
require 'rest-core'

module RestGW2
  Client = RC::Builder.client do
    use RC::DefaultSite   , 'https://api.guildwars2.com/'
    use RC::DefaultHeaders, {'Accept' => 'application/json'}
    use RC::Oauth2Header  , 'Bearer', nil

    use RC::Timeout       , 30
    use RC::ErrorHandler  , lambda{ |env| RestGW2::Error.call(env) }
    use RC::ErrorDetectorHttp

    use RC::JsonResponse  , true
    use RC::CommonLogger  , nil
    use RC::Cache         , nil, 600
  end

  class Error < RestCore::Error
    include RestCore

    class ServerError         < Error; end
    class ClientError         < Error; end

    class BadRequest          < ClientError; end
    class Unauthorized        < ClientError; end
    class Forbidden           < ClientError; end
    class NotFound            < ClientError; end

    class InternalServerError < ServerError; end
    class BadGateway          < ServerError; end
    class ServiceUnavailable  < ServerError; end

    attr_reader :error, :code, :url
    def initialize error, code, url=''
      @error, @code, @url = error, code, url
      super("[#{code}] #{error.inspect} from #{url}")
    end

    def self.call env
      error, code, url = env[RESPONSE_BODY], env[RESPONSE_STATUS],
                         env[REQUEST_URI]
      return new(error, code, url) unless error.kind_of?(Hash)
      case code
        when 400; BadRequest
        when 401; Unauthorized
        when 403; Forbidden
        when 404; NotFound
        when 500; InternalServerError
        when 502; BadGateway
        when 503; ServiceUnavailable
        else    ; self
      end.new(error, code, url)
    end
  end

  Client.include(Module.new{
    # https://wiki.guildwars2.com/wiki/API:2/account
    # https://wiki.guildwars2.com/wiki/API:2/worlds
    # https://wiki.guildwars2.com/wiki/API:1/guild_details
    def account_with_detail opts={}
      me = get('v2/account', {}, opts)
      worlds = get('v2/worlds', :ids => me['world'])
      guilds = guilds_detail(me['guilds'])
      me.merge('world' => world_detail(worlds.first), 'guilds' => guilds)
    end

    # https://wiki.guildwars2.com/wiki/API:2/account/wallet
    # https://wiki.guildwars2.com/wiki/API:2/currencies
    def wallet_with_detail opts={}
      wallet = get('v2/account/wallet', {}, opts)
      ids = wallet.map{ |w| w['id'] }.join(',')
      currencies = get('v2/currencies', :ids => ids).group_by{ |w| w['id'] }
      wallet.map do |currency|
        currency.merge(currencies[currency['id']].first)
      end.sort_by{ |c| c['order'] }
    end

    # https://wiki.guildwars2.com/wiki/API:2/items
    # https://wiki.guildwars2.com/wiki/API:2/commerce/prices
    def with_item_detail path, opts={}, &block
      block ||= :itself.to_proc
      items = block.call(get(path, {}, opts))
      ids   = items.map{ |i| i && i['id'] }

      detail = ids.compact.each_slice(100).map do |slice|
        query = {:ids => slice.join(',')}
        [get('v2/items', query),
         get('v2/commerce/prices', query, opts)]
      end.flatten.group_by{ |i| i['id'] }

      items.map do |i|
        i && detail[i['id']].inject(i, &:merge).merge('count' => i['count'])
      end
    end

    # https://wiki.guildwars2.com/wiki/API:2/commerce/transactions
    def transactions_with_detail path, opts={}
      with_item_detail("v2/commerce/transactions/#{path}", opts) do |trans|
        trans.map do |t|
          t.merge('id' => t['item_id'], 'count' => t['quantity'])
        end
      end
    end

    def transactions_with_detail_compact path, opts={}
      transactions_with_detail(path, opts).inject([]) do |ret, trans|
        last = ret.last
        if last && last['item_id'] == trans['item_id'] &&
                   last['price']   == trans['price']
           last['count'] += trans['count']
        else
          ret << trans
        end
        ret
      end
    end

    private
    # https://wiki.guildwars2.com/wiki/API:2/worlds
    def world_detail world
      region = case r = world['id'] / 1000
               when 1
                 'North America'
               when 2
                 'Europe'
               else
                 "Unknown (#{r})"
               end
      lang   = case r = (world['id'] % 1000) / 100
               when 0
                 'English'
               when 1
                 'French'
               when 2
                 'German'
               when 3
                 'Spanish'
               else
                 "Unknown (#{r})"
               end
      "#{world['name']} (#{world['population']}) / #{region} (#{lang})"
    end

    # https://wiki.guildwars2.com/wiki/API:1/guild_details
    def guilds_detail guilds
      guilds.map do |gid|
        get('v1/guild_details', :guild_id => gid)
      end.map do |guild|
        "#{guild['guild_name']} [#{guild['tag']}]"
      end
    end
  })
end
