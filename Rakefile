
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
  s.add_runtime_dependency('rest-core', '>=3.5.92')
  %w[jellyfish rack rack-handlers
     dalli lru_redux].each{ |g| s.add_development_dependency(g) }

  # exclude rest-core
  s.files.reject!{ |f| f.start_with?('rest-core/') }
end
