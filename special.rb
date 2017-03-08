
require 'time'
require 'pp'

require './monkey'
require './util'

CachedData = Struct.new(:mtime, :response)

class Cacher

  @@threads = []

  def self.stop
    @@threads.each(&:kill)
  end

  def initialize app, maxage=300
    @app = app
    @cache = {}
    @maxage = maxage

    @@threads << Thread.new {
      loop do
        sleep (@maxage / 2)
        self.gc
      end
    }
  end

  def call env
    log_self

    key = [env[REQUEST_METHOD], env[REAL_PATH], env[VIEW]]
    data = CachedData.new(nil, [400, {}, []])
  
    if data.mtime.nil? || data.mtime < env[REAL_PATH].mtime ||
      ('GET' == env[REQUEST_METHOD] and not env[VIEW]::CACHING)
      data.mtime = env[REAL_PATH].mtime
      env[CHANGE_TIMES] << data.mtime
      data.response = @app.(env)
    end

    @cache[key] = data unless data.mtime.nil? if env[VIEW]::CACHING
    
    data.response
  end

  def gc
    time = Time.now - @maxage
    @cache.each do |k, v|
      if v.mtime < time
        @cache.delete k
      end
    end
  end
end

class Methods
  def initialize app
    @app = app
  end

  LOAD_TIME = Time.now.fz

  def call env
    log_self
    case env[REQUEST_METHOD]
    when 'HEAD'
      env[NOP_RENDER] = true

      t = nil 
      if t=env[IF_MODIFIED_SINCE]
        t = Time.httpdate t
      end

      res = @app.(env)

      if t
        tx = env[CHANGE_TIMES].max
        
        res[0] = 
          if tx.nil?
            304
          elsif t < tx || t <= LOAD_TIME
            204
          else
            304
          end
      end

      res
    when 'GET'
      @app.(env)
    else
      env[STATUS_CODE] = 406
      env[ERROR_MESSAGE] = "#{env[REQUEST_METHOD]} recieved, but only GET and HEAD are supported."
      env[ADDITIONAL_HEADERS] = {'Allowed' => 'GET, HEAD'}
      throw(ERROR)
    end
  end
end

