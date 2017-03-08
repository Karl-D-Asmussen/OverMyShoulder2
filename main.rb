#!/usr/bin/ruby2.3

require 'thin'
require 'mono_logger'
require 'logger'
require 'docopt'

require './errors'
require './monkey'
require './pages'
require './special'
require './util'
require './views'

CONFIG = Docopt::docopt <<-END rescue (puts $!.message; exit 2)
Usage:
  server [options]

Options:
  -h, --help               print this message
  -iIP, --ip=IP            assign IP address [default: 127.0.0.1]
  -pPORT, --port=PORT      assign TCP port [default: 8080]
  -dDIR, --directory=DIR   set root directory to serve files from [default: .]
  -lLOG, --log=LOG         log file name [default: ./log.log]
END

IP = CONFIG['--ip']
PORT = CONFIG['--port'].to_i
PATH = CONFIG['--directory']
LOG = CONFIG['--log']

Thin::Logging.silent = true
Thin::Logging.debug = false
Thin::Logging.logger = MonoLogger.new (LOG.to_p.open('a').tap {|f| f.sync = true })
Thin::Logging.level = Logger::INFO

Server = Thin::Server.new(IP, PORT, signals: false) do
  use Rack::CommonLogger, Thin::Logging.logger
  use Rack::CommonLogger, STDERR
  use MHD
  use ThrowCode
  use ErrorHandler
  use Methods

  map('/') {
    use Paths, PATH
    use ViewDecider
    use Cacher

    run Render

  }

  run proc { |env|
    env[STATUS_CODE] = 500
    env[ERROR_MESSAGE] = "unreachable"
    throw ERROR
  }
end

Thin::Logging.debug = true

trap :INT do
  exit 0
end

Server.start
