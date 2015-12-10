
require 'rest-core'

module RestGW2
  Client = RC::Builder.client do
    use RC::DefaultSite   , 'https://api.guildwars2.com/v2/'
    use RC::DefaultHeaders, {'Accept' => 'application/json'}
    use RC::Oauth2Header  , 'Bearer', nil

    use RC::Timeout       , 10
    use RC::ErrorHandler  ,
      lambda{ |env| RuntimeError.new(env[RC::RESPONSE_BODY]) }
    use RC::ErrorDetectorHttp

    use RC::JsonResponse  , true
    use RC::CommonLogger  , nil
    use RC::Cache         , nil, 600
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
