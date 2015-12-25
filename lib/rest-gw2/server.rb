
require 'rest-gw2/server/cache'
require 'mime/types'
require 'rest-core'
require 'jellyfish'

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

  module DalliExtension
    def [] *args
      get(*args)
    end

    def []= *args
      set(*args)
    end

    def store *args
      set(*args)
    end
  end

  def self.cache logger
    @cache ||= Cache.pick(logger)
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
        File.read("#{__dir__}/view/#{path}.erb")
      end

      def refresh_path
        path(request.path, :r => '1', :t => t)
      end

      def menu item, title
        href = path(item, :t => t)
        if request.fullpath == href
          title
        else
          %Q{<a href="#{href}">#{title}</a>}
        end
      end

      def menu_trans item, title
        menu("/transactions#{item}", title)
      end

      # HELPER
      def item_wiki item
        page = item['name'].tr(' ', '_')
        img = %Q{<img class="icon" title="#{item_title(item)}"} +
              %Q{ src="#{h item['icon']}"/>}
        %Q{<a href="http://wiki.guildwars2.com/wiki/#{u page}">#{img}</a>}
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

      # CONTROLLER
      def gw2_call msg, *args
        refresh = !!request.GET['r']
        yield(gw2.public_send(msg, *args, 'cache.update' => refresh).itself)
      rescue RestGW2::Error => e
        @error = e.error['text']
        render :error
      end

      def gw2
        Client.new(:access_token => access_token,
                   :log_method => logger(env).method(:info),
                   :cache => RestGW2.cache(logger(env)))
      end

      # ACCESS TOKEN
      def access_token
        decrypted_access_token || ENV['RESTGW2_ACCESS_TOKEN']
      rescue ArgumentError, OpenSSL::Cipher::CipherError => e
        raise RestGW2::Error.new({'text' => e.message}, 0)
      end

      def decrypted_access_token
        decrypt(t) if t
      end

      def t
        @t ||= begin
          r = request.GET['t']
          r if r && !r.strip.empty?
        end
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

    get '/bank' do
      gw2_call(:with_item_detail, 'v2/account/bank') do |items|
        @items = items
        render :items
      end
    end

    get '/materials' do
      gw2_call(:with_item_detail, 'v2/account/materials') do |items|
        @items = items
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
      gw2_call(:transactions_with_detail, 'current/buys') do |trans|
        @trans = trans
        @total = sum_trans(trans)
        render :transactions
      end
    end

    get '/transactions/selling' do
      gw2_call(:transactions_with_detail, 'current/sells') do |trans|
        @trans = trans
        @total = sum_trans(trans)
        render :transactions
      end
    end

    get '/transactions/bought' do
      gw2_call(:transactions_with_detail_compact, 'history/buys') do |trans|
        @trans = trans
        @total = sum_trans(trans)
        render :transactions
      end
    end

    get '/transactions/sold' do
      gw2_call(:transactions_with_detail_compact, 'history/sells') do |trans|
        @trans = trans
        @total = sum_trans(trans)
        render :transactions
      end
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
