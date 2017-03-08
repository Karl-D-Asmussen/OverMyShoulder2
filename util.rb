
require 'pathname'
require 'pp'

require './monkey'

$ASSERTIONS = 1

class Assertion < Exception; end

def location
  caller_locations(2, 1)[0].label
end

def assert msg='assertion', level: 1, &block
  raise Assertion, "#{msg} failed in `#{location}'" unless
    block.() if
      level >= $ASSERTIONS
end

NAME = 'MHD\'s'.fz
REQUEST_METHOD = 'REQUEST_METHOD'.fz
IF_MODIFIED_SINCE = 'HTTP_IF_MODIFIED_SINCE'.fz
SCRIPT_NAME = 'SCRIPT_NAME'.fz
PATH_INFO = 'PATH_INFO'.fz
QUERY = 'QUERY_STRING'.fz

CHANGE_TIMES = 'mhd.change-times'.fz
REAL_PATH = 'mhd.real-path'.fz
URL_PATH = 'mhd.url-path'.fz
STATUS_CODE = 'mhd.status-code'.fz
ERROR_MESSAGE = 'mhd.error-message'.fz
ADDITIONAL_HEADERS = 'mhd.additional-headers'.fz

DISPOSITION = 'mhd.disposition'.fz
NOP_RENDER = 'mhd.nop-render'.fz
VIEW = 'mhd.view'.fz

class MHD
  def initialize app
    @app = app
  end

  def call env
    log_self
    env[CHANGE_TIMES] = []
    env[REAL_PATH] = nil
    env[URL_PATH] = nil
    env[STATUS_CODE] = nil
    env[ERROR_MESSAGE] = nil
    env[ADDITIONAL_HEADERS] = {}

    env[NOP_RENDER] = nil
    env[VIEW] = nil
    env[DISPOSITION] = 'inline'

    res = @app.(env)
  end
end

class Paths

  def initialize app, base='.'

    @app = app
    @base = base.to_p

  end

  def self.exclude s
    s = s.basename.to_s
    ?. == s[0] || ?~ == s[-1]
  end
   
  def call env
    log_self

    script = '/'.to_p + env[SCRIPT_NAME]
    info = env[PATH_INFO].to_p.unroot

    env[URL_PATH] = script / info
    path = env[REAL_PATH] = @base / info

    throw(ERROR, 403, "No '..' allowed in paths below '#{script}'.") if
      info.each_filename.to_set.member? '..'
    
    if not path.exist? or self.class::exclude(path)
      env[STATUS_CODE] = 404
      env[ERROR_MESSAGE] = "Path '#{info}' under '#{script}' doesn't exist."
      throw(ERROR)
    end

    @app.(env)
  end
end
