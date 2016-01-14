
require 'rest-gw2/server/cache'
require 'rest-gw2/client'
require 'mime/types'
require 'rest-core'
require 'jellyfish'
require 'rack'

require 'timeout'
require 'openssl'
require 'erb'
require 'cgi'

module RestGW2
  CONFIG = ENV['RESTGW2_CONFIG'] || File.expand_path("#{__dir__}/../../.env")

  def self.extract_env path
    return {} unless File.exist?(path)
    Hash[File.read(path).strip.squeeze("\n").each_line.map do |line|
      name, value = line.split('=')
      [name, value.chomp] if name && value
    end.compact]
  end

  extract_env(CONFIG).each do |k, v|
    ENV[k] ||= v
  end

  class ServerCore
    include Jellyfish
    SECRET = ENV['RESTGW2_SECRET'] || 'RESTGW2_SECRET'*2
    COINS  = %w[gold silver copper].zip(%w[
      https://wiki.guildwars2.com/images/d/d1/Gold_coin.png
      https://wiki.guildwars2.com/images/3/3c/Silver_coin.png
      https://wiki.guildwars2.com/images/e/eb/Copper_coin.png
    ]).freeze

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
      def render path
        erb(:layout){ erb(path) }
      end

      def erb name, arg=nil, &block
        ERB.new(views(name)).result(binding, &block)
      end

      def h str
        CGI.escape_html(str) if str.kind_of?(String)
      end

      def u str
        CGI.escape(str) if str.kind_of?(String)
      end

      def path str, q={}
        RC::Middleware.request_uri(
          RC::REQUEST_PATH => "#{ENV['RESTGW2_PREFIX']}#{str}",
          RC::REQUEST_QUERY => q)
      end

      def views name
        @views ||= {}
        @views[name] = File.read("#{__dir__}/view/#{name}.erb")
      end

      def refresh_path
        path(request.path, :p => p, :r => '1', :t => t)
      end

      # TODO: clean me up
      def menu item, title, query={}
        href = path(item, query.merge(:t => t))
        if path(request.path, :p => p, :t => t) == href
          title
        else
          %Q{<a href="#{href}">#{title}</a>}
        end
      end

      # TODO: clean me up
      def menu_sub prefix, item, title
        key = "#{prefix}#{item}"
        if path(request.path) == path(key)
          menu(key, title, :p => p)
        else
          menu(key, title)
        end
      end

      def menu_char name
        menu("/characters/#{RC::Middleware.escape(name)}", name)
      end

      def menu_skin item, title
        menu_sub('/skins', item, title)
      end

      def menu_trans item, title
        menu_sub('/transactions', item, title)
      end

      def page num
        menu(request.path, num.to_s, :p => zero_is_nil(num))
      end

      # HELPER
      def blank_icon
        %Q{<img class="icon" src="https://upload.wikimedia.org/wikipedia/commons/d/d2/Blank.png"/>}
      end

      def item_wiki_list items
        items.map(&method(:item_wiki)).join("\n")
      end

      def item_wiki item
        if item['name'] && item['icon']
          page = item['name'].tr(' ', '_')
          missing = if item['count'] == 0 then ' missing' else nil end
          img = %Q{<img class="icon#{missing}" title="#{item_title(item)}"} +
                %Q{ src="#{h item['icon']}"/>}
          %Q{<a href="http://wiki.guildwars2.com/wiki/#{u page}">#{img}</a>}
        else
          blank_icon
        end
      end

      def item_link item
        name = item_name(item)
        if item['nolink']
          name
        else
          menu("/items/#{item['id']}", name)
        end
      end

      def item_name item
        h(item['name'] || "?#{item['id']}?")
      end

      def item_title item
        d = item['description']
        d && d.unpack('U*').map{ |c| "&##{c};" }.join
      end

      def item_count item
        c = item['count']
        "(#{c})" if c > 1
      end

      def item_price item
        b = item['buys']
        s = item['sells']
        bb = b && price(b['unit_price'])
        ss = s && price(s['unit_price'])
        %Q{#{bb} / #{ss}} if bb || ss
      end

      def price copper
        g = copper / 100_00
        s = copper % 100_00 / 100
        c = copper % 100
        l = [g, s, c]
        n = l.index(&:nonzero?)
        return '-' unless n
        l.zip(COINS).drop(n).map do |(num, (title, src))|
          %Q{#{num}<img class="price" title="#{h title}" src="#{h src}"/>}
        end.join(' ')
      end

      def dye_color dye
        %w[cloth leather metal].map do |kind|
          rgb = dye[kind]['rgb']
          rgb && dye_preview(kind, rgb.join(', '))
        end.join("\n")
      end

      def dye_preview kind, rgb
        %Q{<span class="icon" title="#{kind}, rgb(#{rgb})"} +
             %Q{ style="background-color: rgb(#{rgb})"></span>}
      end

      def abbr_time_ago time, precision=1
        return unless time
        ago = time_ago(time)
        short = ago.take(precision).join(' ')
        %Q{(<abbr title="#{time}, #{ago.join(' ')} ago">#{short} ago</abbr>)}
      end

      def time_ago time
        duration((Time.now - Time.parse(time)).to_i)
      end

      def duration delta
        result = []

        [[ 60, :seconds],
         [ 60, :minutes],
         [ 24, :hours  ],
         [365, :days   ],
         [999, :years  ]].
          inject(delta) do |length, (divisor, name)|
            quotient, remainder = length.divmod(divisor)
            result.unshift("#{remainder} #{name}")
            break if quotient == 0
            quotient
          end

        result
      end

      def sum_trans trans
        trans.inject(0) do |sum, t|
          sum + t['price'] * t['quantity']
        end
      end

      def sum_items items
        items.inject([0, 0]) do |sum, i|
          next sum unless i
          b = i['buys']
          s = i['sells']
          sum[0] += b['unit_price'] * i['count'] if b
          sum[1] += s['unit_price'] * i['count'] if s
          sum
        end
      end

      def all_items
        bank, mats, chars = all_items_defer
        flatten_chars = chars.flat_map do |c|
          c['equipment'] +
            c['bags'] +
            c['bags'].flat_map{ |c| c && c['inventory'] }
        end
        (bank + mats + flatten_chars).compact.
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
        bank, mats, chars = all_items_defer
        [select_item(bank.compact, id), select_item(mats.compact, id),
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
        bank  = gw2_defer(:with_item_detail, 'v2/account/bank')
        mats  = gw2_defer(:with_item_detail, 'v2/account/materials')
        chars = gw2_defer(:characters_with_detail).map do |c|
          c['equipment'] = gw2_defer(:expand_item_detail, c['equipment'])
          c['bags']      = gw2_defer(:bags_with_detail  , c['bags'])
          c
        end
        [bank, mats, chars]
      end

      # CONTROLLER
      def gw2_request msg, *args, &block
        protect do
          gw2_call(msg, *args, &block)
        end
      end

      def gw2_defer msg, *args, &block
        gw2.class.defer do
          gw2_call(msg, *args, &block)
        end
      end

      def gw2_call msg, *args, &block
        block ||= :itself.to_proc
        refresh = !!request.GET['r']
        opts = {'cache.update' => refresh, 'expires_in' => 600}
        args << {} if msg == :with_item_detail
        block.call(gw2.public_send(msg, *args, opts).itself)
      end

      def protect
        yield
      rescue RestGW2::Error => e
        @error = e.error['text']
        render :error
      end

      def skin_request type, subtype=nil, weight=nil
        gw2_request(:skins_with_detail) do |items|
          @items = items.select do |i|
            i['type'] == type &&
              (subtype.nil? || subtype == i['details']['type']) &&
              (weight.nil? || weight == i['details']['weight_class'])
          end
          @buy, @sell = sum_items(items)
          @skin_submenu = "menu_#{type.downcase}s" if subtype
          @subtype = subtype.downcase if subtype
          @weight = weight.downcase if weight
          @unlocked = @items.count{ |i| i['count'] > 0 }
          render :skins
        end
      end

      def trans_request msg, path
        gw2_request(msg, path, :page => p) do |trans|
          @pages = calculate_pages("v2/commerce/transactions/#{path}")
          @trans = trans
          @total = sum_trans(trans)
          render :transactions
        end
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
        Client.new(:access_token => access_token,
                   :log_method => logger(env).method(:info),
                   :cache => RestGW2::Cache.default(logger(env)))
      end

      # ACCESS TOKEN
      def access_token
        t && decrypt(t) || ENV['RESTGW2_ACCESS_TOKEN']
      rescue ArgumentError, OpenSSL::Cipher::CipherError => e
        raise RestGW2::Error.new({'text' => e.message}, 0)
      end

      def t
        @t ||= begin
          r = request.GET['t']
          r if r && !r.strip.empty?
        end
      end

      def p
        @p ||= zero_is_nil(request.GET['p'])
      end

      def zero_is_nil n
        r = n.to_i
        r if r != 0
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
      @error = 'Timeout. Please try again.'
      render :error
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
      gw2_request(:account_with_detail) do |account|
        @info = account
        render :info
      end
    end

    get '/characters' do
      gw2_request(:characters_with_detail) do |chars|
        @chars = chars
        @total = chars.inject(0){ |t, c| t + c['age'] }
        @craftings = group_by_crafting(chars)
        render :characters
      end
    end

    get %r{\A/characters/(?<name>[\w ]+)\z} do |m|
      gw2_request(:characters_with_detail) do |characters|
        @names = characters.map { |c| c['name'] }
        name   = m[:name]
        char   = characters.find{ |c| c['name'] == name }

        equi = gw2_defer(:expand_item_detail, char['equipment'])
        bags = gw2_defer(:bags_with_detail  , char['bags'])

        protect do
          @equi = equi
          @bags = bags

          @equi_buy, @equi_sell = sum_items(@equi)
          @bags_buy, @bags_sell = sum_items(@bags +
                                    @bags.flat_map{ |c| c && c['inventory'] })
          render :profile
        end
      end
    end

    get '/dyes' do
      gw2_request(:dyes_with_detail) do |dyes|
        @dyes = dyes
        @buy, @sell = sum_items(dyes)
        @unlocked = dyes.count{ |d| d['count'] > 0 }
        render :dyes
      end
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

    get '/minis' do
      gw2_request(:minis_with_detail) do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/achievements' do
      render :wip
    end

    get '/bank' do
      gw2_request(:with_item_detail, 'v2/account/bank') do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/materials' do
      gw2_request(:with_item_detail, 'v2/account/materials') do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/wallet' do
      gw2_request(:wallet_with_detail) do |wallet|
        @wallet = wallet
        render :wallet
      end
    end

    get '/items' do
      protect do
        @items = all_items
        @buy, @sell = sum_items(@items)
        render :items
      end
    end

    get %r{\A/items/(?<id>\d+)\z} do |m|
      protect do
        items = find_my_item(m[:id].to_i)
        @bank, @materials, @chars = items
        @buy, @sell = sum_items(@bank + @materials + @chars.values.flatten)
        render :items_from
      end
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
      gw2_request(:get, 'v2/tokeninfo') do |info|
        @info = info
        render :info
      end
    end
  end

  Server = Jellyfish::Builder.app do
    use Rack::CommonLogger
    use Rack::Chunked
    use Rack::ContentLength
    use Rack::Deflater
    use Rack::ContentType, 'text/html; charset=utf-8'

    map '/assets' do
      run Rack::Directory.new('public')
    end

    map '/' do
      run ServerCore.new
    end
  end
end
