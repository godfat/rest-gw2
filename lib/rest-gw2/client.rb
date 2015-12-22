
require 'rest-core'

module RestGW2
  Client = RC::Builder.client do
    use RC::DefaultSite   , 'https://api.guildwars2.com/v2/'
    use RC::DefaultHeaders, {'Accept' => 'application/json'}
    use RC::Oauth2Header  , 'Bearer', nil

    use RC::Timeout       , 10
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
    def with_item_detail path, query={}
      items = get(path, query)
      ids   = items.map{ |i| i && i['id'] }

      detail = ids.compact.each_slice(100).map do |slice|
        get('items', :ids => slice.join(','))
      end.flatten.group_by{ |i| i['id'] }

      items.map{ |i| i && detail[i['id']].first.merge('count' => i['count']) }
    end
  })
end
