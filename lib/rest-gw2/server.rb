
require 'rest-gw2/server/cache'
require 'jellyfish'

require 'openssl'
require 'erb'

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
    controller_include Module.new{
      # VIEW
      def render path
        erb(:layout){ erb(path) }
      end

      def erb path, &block
        ERB.new(views(path)).result(binding, &block)
      end

      def path str
        "#{ENV['RESTGW2_PREFIX']}#{str}"
      end

      def views path
        @views ||= {}
        @views[path] ||= File.read("#{__dir__}/view/#{path}.erb")
      end

      def menu item
        if t
          path("#{item}?t=#{t}")
        else
          path(item)
        end
      end

      # HELPER
      def item_title item
        d = item['description']
        d && d.unpack('U*').map{ |c| "&##{c};" }.join
      end

      # CONTROLLER
      def gw2_call msg, *args
        yield(gw2.public_send(msg, *args).itself)
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
        @account = account
        render :account
      end
    end

    get '/bank' do
      gw2_call(:with_item_detail, 'v2/account/bank') do |items|
        @items = items
        render :bank
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
