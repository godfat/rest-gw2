
require 'rest-gw2'

module RestGW2::Runner
  module_function
  def options
    @options ||=
      [['Options:'           , ''                             ],
       ['-o, --host HOST'    , 'Use HOST (default: 0.0.0.0)'  ],
       ['-p, --port PORT'    , 'Use PORT (default: 8080)'     ],
       ['-s, --server SERVER', 'Use SERVER (default: webrick)'],
       ['-c, --configru'     , 'Print where the config.ru is' ],
       ['-h, --help'         , 'Print this message'           ],
       ['-v, --version'      , 'Print the version'            ]]
  end

  def root
    File.expand_path("#{__dir__}/../../../")
  end

  def config_ru_path
    "#{root}/config.ru"
  end

  def run argv=ARGV
    unused, host, port, server = parse(argv)
    warn("Unused arguments: #{unused.inspect}") unless unused.empty?
    require 'rack'
    Rack::Handler.get(server).run(Rack::Builder.new{
      eval(File.read(RestGW2::Runner.config_ru_path))
    }.to_app, :Host => host, :Port => port, :config => root)
  end

  def parse argv
    unused, host, port, server = [], '0.0.0.0', 8080, 'webrick'
    until argv.empty?
      case arg = argv.shift
      when /^-o=?(.+)?/, /^--host=?(.+)?/
        host = $1 || argv.shift
        missing_arg('host') unless host

      when /^-p=?(.+)?/, /^--port=?(.+)?/
        port = $1 || argv.shift
        missing_arg('port') unless port

      when /^-s=?(.+)?/, /^--server=?(.+)?/
        server = $1 || argv.shift
        missing_arg('server') unless server

      when /^-c/, '--configru'
        puts(config_ru_path)
        exit

      when /^-h/, '--help'
        puts(help)
        exit

      when /^-v/, '--version'
        require 'rest-gw2/version'
        puts(RestGW2::VERSION)
        exit

      else
        unused << arg
      end
    end

    [unused, host, port, server]
  end

  def parse_next argv, arg
    argv.unshift("-#{arg[2..-1]}") if arg.size > 2
  end

  def missing_arg arg
    warn("Missing argument: #{arg}")
    exit(1)
  end

  def help
    optt = options.transpose
    maxn = optt.first.map(&:size).max
    maxd = optt.last .map(&:size).max
    "Usage: rest-gw2 [OPTIONS]\n" +
    options.map{ |(name, desc)|
      if name.end_with?(':')
        name
      else
        sprintf("  %-*s  %-*s", maxn, name, maxd, desc)
      end
    }.join("\n")
  end
end
