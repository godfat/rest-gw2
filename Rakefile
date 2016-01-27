
begin
  require "#{dir = File.dirname(__FILE__)}/task/gemgem"
rescue LoadError
  sh 'git submodule update --init --recursive'
  exec Gem.ruby, '-S', $PROGRAM_NAME, *ARGV
end

$LOAD_PATH.unshift(File.expand_path("#{dir}/rest-core/lib"))
$LOAD_PATH.unshift(File.expand_path("#{dir}/rest-core/promise_pool/lib"))

desc 'Run console'
task 'console' do
  ARGV.shift
  ARGV.unshift 'rack'
  load `which rib`.chomp
end

desc 'Run server'
task 'server' do
  ARGV.shift
  load 'bin/rest-gw2'
end

Gemgem.init(dir) do |s|
  require 'rest-gw2/version'
  s.name    = 'rest-gw2'
  s.version = RestGW2::VERSION
  s.add_runtime_dependency('rest-core', '>=4')
  %w[jellyfish rack rack-handlers
     dalli lru_redux].each{ |g| s.add_development_dependency(g) }

  # exclude rest-core
  s.files.reject!{ |f| f.start_with?('rest-core/') }
end
