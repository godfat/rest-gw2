
require 'rest-gw2'
warmup do
  RestGW2::Client.new
end
run RestGW2::Server
