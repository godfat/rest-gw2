
require 'rest-gw2/server/cache'
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
    controller_include Module.new{
      # VIEW
      def render path
        erb(:layout){ erb(path) }
      end

      def erb path, &block
        ERB.new(views(path)).result(binding, &block)
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

      def views path
        @views ||= {}
        @views[path] = File.read("#{__dir__}/view/#{path}.erb")
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
      def menu_trans item, title
        key = "/transactions#{item}"
        if path(request.path) == path(key)
          menu(key, title, :p => p)
        else
          menu(key, title)
        end
      end

      def page num
        menu(request.path, num.to_s, :p => zero_is_nil(num))
      end

      # HELPER
      def blank_icon
        %Q{<img class="icon" src="https://upload.wikimedia.org/wikipedia/commons/d/d2/Blank.png"/>}
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

      def time_ago time, precision=1
        delta = (Time.now - Time.parse(time)).to_i
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

      # CONTROLLER
      def gw2_call msg, *args
        refresh = !!request.GET['r']
        opts = {'cache.update' => refresh, 'expires_in' => 600}
        yield(gw2.public_send(msg, *args, opts).itself)
      rescue RestGW2::Error => e
        @error = e.error['text']
        render :error
      end

      def trans_call msg, path, &block
        gw2_call(msg, path, :page => p) do |trans|
          @pages = calculate_pages("v2/commerce/transactions/#{path}")
          @trans = trans
          @total = sum_trans(trans)
          render :transactions
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
        cipher = OpenSSL::Cipher.new('aes-128-gcm')
        cipher.encrypt
        cipher.key = SECRET
        iv = cipher.random_iv
        encrypted = cipher.update(data) + cipher.final
        tag = cipher.auth_tag
        encode_base64(iv, encrypted, tag)
      end

      def decrypt data
        iv, encrypted, tag = decode_base64(data)
        decipher = OpenSSL::Cipher.new('aes-128-gcm')
        decipher.decrypt
        decipher.key = SECRET
        decipher.iv = iv
        decipher.auth_tag = tag
        decipher.update(encrypted) + decipher.final
      end

      def encode_base64 *data
        data.map{ |d| [d].pack('m0') }.join('.').tr('+/=', '-_~')
      end

      def decode_base64 str
        str.split('.').map{ |d| d.tr('-_~', '+/=').unpack('m0').first }
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
      gw2_call(:account_with_detail) do |account|
        @info = account
        render :info
      end
    end

    get '/characters' do
      render :wip
    end

    get '/dyes' do
      gw2_call(:dyes_with_detail) do |dyes|
        @dyes = dyes
        @buy, @sell = sum_items(dyes)
        render :dyes
      end
    end

    get '/skins' do
      render :wip
    end

    get '/minis' do
      gw2_call(:minis_with_detail) do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/achievements' do
      render :wip
    end

    get '/bank' do
      gw2_call(:with_item_detail, 'v2/account/bank') do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/materials' do
      gw2_call(:with_item_detail, 'v2/account/materials') do |items|
        @items = items
        @buy, @sell = sum_items(items)
        render :items
      end
    end

    get '/wallet' do
      gw2_call(:wallet_with_detail) do |wallet|
        @wallet = wallet
        render :wallet
      end
    end

    get '/transactions/buying' do
      trans_call(:transactions_with_detail, 'current/buys')
    end

    get '/transactions/selling' do
      trans_call(:transactions_with_detail, 'current/sells')
    end

    get '/transactions/bought' do
      trans_call(:transactions_with_detail_compact, 'history/buys')
    end

    get '/transactions/sold' do
      trans_call(:transactions_with_detail_compact, 'history/sells')
    end

    get '/tokeninfo' do
      gw2_call(:get, 'v2/tokeninfo') do |info|
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
