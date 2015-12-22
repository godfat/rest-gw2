
require 'rest-gw2/server/cache'

require 'jellyfish'

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
    controller_include Module.new{
      def render path
        erb(:layout){ erb(path) }
      end

      def item_title item
        t = item['description']
        t && t.unpack('U*').map{ |c| "&##{c};" }.join
      end

      def gw2_call msg, *args
        [gw2.public_send(msg, *args).itself, nil]
      rescue RestGW2::Error => e
        [nil, e.error['text']]
      end

      private
      def erb path, &block
        ERB.new(views(path)).result(binding, &block)
      end

      def views path
        @views ||= {}
        @views[path] ||= File.read("#{__dir__}/view/#{path}.erb")
      end

      def logger env
        env['rack.logger'] || begin
          require 'logger'
          Logger.new(env['rack.errors'])
        end
      end

      def gw2
        Client.new(:access_token => ENV['ACCESS_TOKEN'],
                   :log_method => logger(env).method(:info),
                   :cache => RestGW2.cache(logger(env)))
      end
    }

    get '/bank' do
      @items, @error = gw2_call(:with_item_detail, 'account/bank')
      if @items
        render :bank
      elsif @error
        render :error
      else
        raise "Impossible"
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
