
begin
  require "#{dir = File.dirname(__FILE__)}/task/gemgem"
rescue LoadError
  sh 'git submodule update --init'
  exec Gem.ruby, '-S', $PROGRAM_NAME, *ARGV
end

Gemgem.init(dir) do |s|
  require 'rest-gw2/version'
  s.name    = 'rest-gw2'
  s.version = RestGW2::VERSION
  %w[rest-core].each{ |g| s.add_runtime_dependency(g) }
  %w[rack dalli lru_redux].each{ |g| s.add_development_dependency(g) }
end
