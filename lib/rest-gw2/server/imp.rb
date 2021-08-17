# frozen_string_literal: true

require 'rest-gw2/server/cache'
require 'rest-gw2/server/view'
require 'rest-gw2/client'

require 'rest-core'
require 'jellyfish'

require 'uri'
require 'timeout'
require 'openssl'

module RestGW2
  module ServerImp
    SECRET = (ENV['RESTGW2_SECRET'] || 'RESTGW2_SECRET'*2)[0, 16]

    GemIcon = 'https://render.guildwars2.com/' \
      'file/220061640ECA41C0577758030357221B4ECCE62C/502065.png'
    GoldIcon = 'https://render.guildwars2.com/' \
      'file/98457F504BA2FAC8457F532C4B30EDC23929ACF9/619316.png'

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
      guilds = gw2_request(:account_with_detail)['guilds'].
        group_by{ |g| g['id'] }.inject({}){ |r, (id, v)| r[id] = v.first; r }

      if guilds[gid]
        yield(:gid => gid, :guilds => guilds)
      else
        status 404
        render :error, "Cannot find guild id: #{gid}"
      end
    end

    def skin_request type, subtype=nil, weight=nil, &block
      items = gw2_request(:skins_with_detail).select do |i|
        filter_skin(i, type, subtype, weight, &block)
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

    def filter_skin item, type, subtype, weight
      item['type'] == type &&
        if block_given?
          yield(item)
        else
          (subtype.nil? || subtype == item.dig('details', 'type')) &&
          (weight.nil? || weight == item.dig('details', 'weight_class'))
        end
    end

    def trans_request msg, path
      items = gw2_request(msg, path, :page => view.query_p)
      total = view.sum_trans(items)
      pages = calculate_pages("v2/commerce/transactions/#{path}")

      render :commerce, :items => items, :total => total, :pages => pages
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

    def stub_gold num, count=nil
      count ||=
        gw2_request(:get, 'v2/commerce/exchange/gems', :quantity => num)

      {'name' => 'Gold', 'icon' => GoldIcon, 'price' => num, 'count' => count}
    end

    def stub_gem num, count=nil
      count ||=
        gw2_request(:get, 'v2/commerce/exchange/coins', :quantity => num)

      {'name' => 'Gem', 'icon' => GemIcon, 'price' => num, 'count' => count}
    end

    def resolve_count item
      item['coins_per_gem'] = item['count']['coins_per_gem']
      item['count'] = item['count']['quantity']
      item
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
  end
end
