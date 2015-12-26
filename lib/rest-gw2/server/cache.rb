
module RestGW2
  module Cache
    module DalliExtension
      def [] *args
        get(*args)
      end

      def []= *args
        set(*args)
      end

      def store key, value, expires_in: nil
        set(key, value, expires_in)
      end
    end

    module_function
    def default logger
      @cache ||= Cache.pick(logger)
    end

    def pick logger
      memcache(logger) || lru_cache(logger)
    end

    def memcache logger
      require 'dalli'
      client = Dalli::Client.new
      File.open(IO::NULL) do |null|
        Dalli.logger = Logger.new(null)
        client.alive!
        Dalli.logger = logger
      end
      logger.info("Memcached connected to #{client.version.keys.join(', ')}")
      client.extend(DalliExtension)
      client
    rescue LoadError, Dalli::RingError => e
      logger.debug("Skip memcached because: #{e}")
      nil
    end

    def lru_cache logger
      require 'lru_redux'
      logger.info("LRU cache size: 100")
      LruRedux::ThreadSafeCache.new(100)
    rescue LoadError => e
      logger.debug("Skip LRU cache because: #{e}")
      nil
    end
  end
end
