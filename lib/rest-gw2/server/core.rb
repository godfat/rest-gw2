
require 'rest-gw2/server/cache'
require 'rest-gw2/server/view'
require 'rest-gw2/client'

require 'rest-core'
require 'jellyfish'

require 'uri'
require 'timeout'
require 'openssl'

module RestGW2
  class ServerCore
    include Jellyfish

    SECRET = ENV['RESTGW2_SECRET'] || 'RESTGW2_SECRET'*2

    def self.weapons
      %w[Greatsword Sword Hammer Mace Axe Dagger
         Staff Scepter
         LongBow ShortBow Rifle Pistol
         Shield Torch Focus Warhorn
         Harpoon Speargun Trident]
    end

    def self.armors
      %w[Helm Shoulders Coat Gloves Leggings Boots HelmAquatic]
    end

    def self.armors_weight
      %w[Light Medium Heavy Clothing]
    end

    def self.crafting
      %w[Weaponsmith Huntsman Artificer
         Armorsmith Leatherworker Tailor
         Jeweler Chef Scribe]
    end

    controller_include NormalizedPath, Module.new{
      # VIEW
      def view
        @view ||= View.new(request, query_t)
      end

      def render *args
        view.render(*args)
      end

      def all_items
        acct, bank, mats, chars = all_items_defer
        flatten_chars = chars.flat_map do |c|
          c['equipment'] +
            c['bags'] +
            c['bags'].flat_map{ |c| c && c['inventory'] }
        end
        (acct + bank + mats + flatten_chars).compact.
          sort_by{ |i| i['name'] || i['id'].to_s }.inject([]) do |r, i|
            last = r.last
            if last && last['id'] == i['id'] &&
               last.values_at('skin', 'upgrades', 'infusions').compact.empty?
              last['count'] += i['count']
            else
              r << i
            end
            r
          end
      end

      def find_my_item id
        acct, bank, mats, chars = all_items_defer
        [select_item(acct.compact, id),
         select_item(bank.compact, id),
         select_item(mats.compact, id),
         chars.inject({}){ |r, c|
           equi = select_item(c['equipment'].compact, id)
           bags = c['bags'].reject(&:nil?).map do |b|
             selected = select_item(b['inventory'].compact, id)
             b.merge('inventory' => selected) if selected.any? ||
                                                 b['id'] == id
           end.compact
           r[c['name']] = [equi, bags] if equi.any? || bags.any?
           r
         }]
      end

      def select_item items, id
        items.select{ |i| i['id'] == id }
      end

      def all_items_defer
        acct  = gw2_defer(:with_item_detail, 'v2/account/inventory')
        bank  = gw2_defer(:with_item_detail, 'v2/account/bank')
        mats  = gw2_defer(:with_item_detail, 'v2/account/materials')
        chars = gw2_defer(:characters_with_detail).map do |c|
          c['equipment'] = gw2_defer(:expand_item_detail, c['equipment'])
          c['bags']      = gw2_defer(:bags_with_detail  , c['bags'])
          c
        end
        [acct, bank, mats, chars]
      end

      # CONTROLLER
      def gw2_request msg, *args
        block ||= :itself.to_proc
        refresh = !!request.GET['r']
        opts = {'cache.update' => refresh, 'expires_in' => Cache::EXPIRES_IN}
        args << {} if msg == :with_item_detail
        key = cache_key(msg, args)
        cache.delete(key) if refresh
        cache.fetch(key) do
          PromisePool::Future.resolve(gw2.public_send(msg, *args, opts))
        end
      end

      def gw2_defer msg, *args
        PromisePool::Promise.new.defer do
          gw2_request(msg, *args)
        end.future
      end

      def guild_request gid
        guilds = gw2_request(:account_with_detail)['guilds']
        if guilds.find{ |g| g['guild_id'] == gid }
          yield(:gid => gid, :guilds => guilds)
        else
          status 404
          render :error, "Cannot find guild id: #{gid}"
        end
      end

      def skin_request type, subtype=nil, weight=nil
        items = gw2_request(:skins_with_detail).select do |i|
          i['type'] == type &&
            (subtype.nil? || subtype == i['details']['type']) &&
            (weight.nil? || weight == i['details']['weight_class'])
        end
        skin_submenu = "menu_#{type.downcase}s" if subtype
        subtype = subtype.downcase if subtype
        weight = weight.downcase if weight
        unlocked = items.count{ |i| i['count'] > 0 }

        render :skins, :items => items,
                       :skin_submenu => skin_submenu,
                       :subtype => subtype,
                       :weight => weight,
                       :unlocked => unlocked
      end

      def trans_request msg, path
        trans = gw2_request(msg, path, :page => view.query_p)
        pages = calculate_pages("v2/commerce/transactions/#{path}")
        total = view.sum_trans(trans)

        render :transactions, :trans => trans, :pages => pages,
                              :total => total
      end

      def group_by_crafting characters
        characters.inject(Hash.new{|h,k|h[k]=[]}) do |group, char|
          char['crafting'].each do |crafting|
            group[crafting['discipline']] <<
              [crafting['rating'], char['name'], crafting['active']]
          end
          group
        end
      end

      def calculate_pages path
        link = gw2.get(path, {:page_size => 200},
                       RC::RESPONSE_KEY => RC::RESPONSE_HEADERS)['LINK']
        pages = RC::ParseLink.parse_link(link)
        parse_page(pages['first']['uri'])..parse_page(pages['last']['uri'])
      end

      def parse_page uri
        RC::ParseQuery.parse_query(URI.parse(uri).query)['page'].to_i
      end

      def gw2
        @gw2 ||= Client.new(:access_token => access_token,
                            :log_method => logger(env).method(:info),
                            :cache => cache)
      end

      def cache
        @cache ||= RestGW2::Cache.default(logger(env))
      end

      def cache_key msg, args
        [msg, *args, access_token].join(':')
      end

      # ACCESS TOKEN
      def access_token
        query_t && decrypt(query_t) || ENV['RESTGW2_ACCESS_TOKEN']
      rescue ArgumentError, OpenSSL::Cipher::CipherError => e
        raise RestGW2::Error.new({'text' => e.message}, 0)
      end

      def query_t
        @query_t ||= begin
          r = request.GET['t']
          r if r && !r.strip.empty?
        end
      end

      # UTILITIES
      def encrypt data
        cipher = new_cipher
        cipher.encrypt
        cipher.key = SECRET
        iv = cipher.random_iv
        encrypted = cipher.update(data) + cipher.final
        tag = auth_tag(cipher)
        encode_base64(iv, encrypted, tag)
      end

      def decrypt data
        iv, encrypted, tag = decode_base64(data)
        cipher = new_cipher
        cipher.decrypt
        cipher.key = SECRET
        cipher.iv = iv
        set_auth_tag(cipher, tag)
        cipher.update(encrypted) + cipher.final
      end

      def encode_base64 *data
        data.map{ |d| [d].pack('m0') }.join('.').tr('+/=', '-_~')
      end

      def decode_base64 str
        str.split('.').map{ |d| d.tr('-_~', '+/=').unpack('m0').first }
      end

      def new_cipher
        OpenSSL::Cipher.new(ENV['CIPHER_ALGO'] || 'aes-128-gcm')
      rescue OpenSSL::Cipher::CipherError
        OpenSSL::Cipher.new('aes-128-cbc')
      end

      def auth_tag cipher
        cipher.respond_to?(:auth_tag) && cipher.auth_tag || ''
      end

      def set_auth_tag cipher, tag
        cipher.respond_to?(:auth_tag=) && cipher.auth_tag = tag
      end

      # MISC
      def logger env
        env['rack.logger'] || begin
          require 'logger'
          Logger.new(env['rack.errors'])
        end
      end
    }

    handle Timeout::Error do
      status 504
      render :error, 'Timeout. Please try again.'
    end

    handle RestGW2::Error do |e|
      status 502
      render :error, e.error['text']
    end

    post '/access_token' do
      t = encrypt(request.POST['access_token'])
      r = request.POST['referrer']
      u = if r == path('/') then path('/account') else r end
      found "#{u}?t=#{t}"
    end

    get '/' do
      render :index
    end

    get '/account' do
      info = gw2_request(:account_with_detail).dup
      info['guilds'] = info['guilds'].map(&view.method(:show_guild))

      render :info, info
    end

    get %r{\A/guilds/(?<uuid>[^/]+)\z} do |m|
      guild_request(m[:uuid]) do |arg|
        members = gw2_defer(:guild_members, arg[:gid])

        render :members, arg.merge(:members => members)
      end
    end

    get %r{\A/guilds/(?<uuid>[^/]+)/items\z} do |m|
      guild_request(m[:uuid]) do |arg|
        stash    = gw2_defer(   :stash_with_detail, arg[:gid])
        treasury = gw2_defer(:treasury_with_detail, arg[:gid])

        render :stash, arg.merge(:stash => stash, :treasury => treasury)
      end
    end

    get '/characters' do
      chars = gw2_request(:characters_with_detail)
      total = chars.inject(0){ |t, c| t + c['age'] }
      craftings = group_by_crafting(chars)

      render :characters, :chars => chars, :total => total,
                          :craftings => craftings
    end

    get %r{\A/characters/(?<name>[\w ]+)\z} do |m|
      characters = gw2_request(:characters_with_detail)
      names = characters.map { |c| c['name'] }
      name  = m[:name]
      char  = characters.find{ |c| c['name'] == name }
      equi  = gw2_defer(:expand_item_detail, char['equipment'])
      bags  = gw2_defer(:bags_with_detail  , char['bags'])

      equi_buy, equi_sell = view.sum_items(equi)
      bags_buy, bags_sell = view.sum_items(bags +
                              bags.flat_map{ |c| c && c['inventory'] })

      render :profile, :names => names, :equi => equi, :bags => bags,
                       :equi_buy => equi_buy, :equi_sell => equi_sell,
                       :bags_buy => bags_buy, :bags_sell => bags_sell
    end

    get '/items' do
      render :items, gw2_request(:with_item_detail, 'v2/account/inventory')
    end

    get '/items/bank' do
      render :items, gw2_request(:with_item_detail, 'v2/account/bank')
    end

    get '/items/materials' do
      render :items, gw2_request(:with_item_detail, 'v2/account/materials')
    end

    get '/items/all' do
      render :items, all_items
    end

    get %r{\A/items/(?<id>\d+)\z} do |m|
      acct, bank, materials, chars = find_my_item(m[:id].to_i)
      buy, sell = view.sum_items(acct + bank + materials +
                                 chars.values.flatten)

      render :items_from, :acct => acct, :bank => bank,
                          :materials => materials, :chars => chars,
                          :buy => buy, :sell => sell
    end

    get '/wallet' do
      render :wallet, gw2_request(:wallet_with_detail)
    end

    get '/skins/backpacks' do
      skin_request('Back')
    end

    weapons.each do |weapon|
      get "/skins/weapons/#{weapon.downcase}" do
        skin_request('Weapon', weapon)
      end
    end

    armors.each do |armor|
      armors_weight.each do |weight|
        get "/skins/armors/#{armor.downcase}/#{weight.downcase}" do
          skin_request('Armor', armor, weight)
        end
      end
    end

    get '/dyes' do
      dyes = gw2_request(:dyes_with_detail)
      buy, sell = view.sum_items(dyes)
      unlocked = dyes.count{ |d| d['count'] > 0 }

      render :dyes, :dyes => dyes,
                    :buy => buy, :sell => sell,
                    :unlocked => unlocked
    end

    get '/minis' do
      render :items, gw2_request(:minis_with_detail)
    end

    get '/achievements/titles' do
      render :titles, gw2_request(:titles_with_detail)
    end

    get '/transactions/buying' do
      trans_request(:transactions_with_detail_compact, 'current/buys')
    end

    get '/transactions/selling' do
      trans_request(:transactions_with_detail_compact, 'current/sells')
    end

    get '/transactions/bought' do
      trans_request(:transactions_with_detail_compact, 'history/buys')
    end

    get '/transactions/sold' do
      trans_request(:transactions_with_detail_compact, 'history/sells')
    end

    get '/tokeninfo' do
      render :info, gw2_request(:get, 'v2/tokeninfo')
    end
  end
end
