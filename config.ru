
require 'rest-gw2'

warmup do
  RestCore.eagerload
  RestCore.eagerload(RestGW2)
  RestGW2::Client.new
end

if pool_size = ENV['GW2_POOL_SIZE']
  RestGW2::Client.pool_size = Integer(pool_size)
end

run RestGW2::Server
