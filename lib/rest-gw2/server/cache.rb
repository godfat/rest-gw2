
module RestGW2
  module Cache
    module_function
    def pick
      memcache || lru_cache
    end

    def memcache
      require 'dalli'
      client = Dalli::Client.new
      client.alive!
      client.extend(DalliExtension)
      client
    rescue LoadError, Dalli::RingError
    end

    def lru_cache
      require 'lru_redux'
      LruRedux::ThreadSafeCache.new(100)
    rescue LoadError
    end
  end
end
