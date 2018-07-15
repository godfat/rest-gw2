
require 'rest-gw2'

warmup do
  RestCore.eagerload
  RestCore.eagerload(RestGW2)
  RestGW2::Client.new
end

run RestGW2::Server
