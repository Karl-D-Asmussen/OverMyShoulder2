
require './util'
require './monkey'
require './pages'


ERROR = Object.new.fz

class ThrowCode
  ERRC = (400 ... 600)

  def initialize app
    @app = app
  end

  def call env
    log_self
    case res =
        catch(ERROR) do
          @app.(env)
        end
    
    when nil
      env[VIEW] = ErrorPage
      Render.call(env)
    when ERRC
      env[STATUS_CODE] = res
      env[VIEW] = ErrorPage
      Render.call(env)
    when [ERRC, String].when
      env[STATUS_CODE] = res[0]
      env[ERROR_MESSAGE] = res[1]
      env[VIEW] = ErrorPage
      Render.call(env)
    else
      res
    end
  
  end
end

class ErrorHandler
  def initialize app
    @app = app
  end
  
  def call env
    log_self
    @app.(env)
  rescue
    env[STATUS_CODE] = 500
    Thin::Logging.log_error(env[ERROR_MESSAGE] = "#$!: #{$!.message}\n#{$@.join("\n    ")}")
    throw ERROR
  end

end
