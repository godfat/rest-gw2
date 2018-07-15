# frozen_string_literal: true

require 'rest-gw2/server/action'

require 'jellyfish'
require 'rack'

module RestGW2
  CONFIG = ENV['RESTGW2_CONFIG'] || File.expand_path("#{__dir__}/../../.env")

  def self.extract_env path
    return {} unless File.exist?(path)
    Hash[File.read(path).strip.squeeze("\n").each_line.map do |line|
      name, value = line.split('=')
      [name, value.chomp] if !line.start_with?('#') && name && value
    end.compact]
  end

  extract_env(CONFIG).each do |k, v|
    ENV[k] ||= v
  end

  Server = Jellyfish::Builder.app do
    use Rack::CommonLogger
    use Rack::Chunked
    use Rack::ContentLength
    use Rack::Deflater
    use Rack::ContentType, 'text/html; charset=utf-8'

    map '/' do
      run ServerAction.new
    end
  end
end
