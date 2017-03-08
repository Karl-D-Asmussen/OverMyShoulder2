require './util'
require './monkey'
require './pages'

VIEW_GUIDE = {
  Dir => DirPage,
  File => DownloadPage,
  :/ => {
    'dir'.fz => DirPage,
    'plain'.fz => LsPage,
  },
  :code => {
    'plain'.fz => LessPage,
    'code'.fz => CodePage,
    'diff'.fz => DiffPage,
  },
  :img => {
    'raw'.fz => RawPage
  },
  '.mkdn'.fz => {
    'plain'.fz => LessPage,
    'code'.fz => CodePage,
    'markdown'.fz => PandocPage,
    'diff'.fz => DiffPage,
    'changes'.fz => ChangesPage,
  },
  '.js'.fz => :code,
  '.rb'.fz => :code,
  '.c'.fz => :code,
  '.sh'.fz => :code,
  '.txt'.fz => {
    'plain'.fz => LessPage,
    'code'.fz => TxtPage,
    'diff'.fz => DiffPage,
  },

  '.jpg'.fz => :img,
  '.png'.fz => :img,
  '.svg'.fz => {
    'raw'.fz => RawPage,
    'code'.fz => CodePage,
    'plain'.fz => LessPage,
    'diff'.fz => DiffPage
  },
  '.gif'.fz => :img,
  '.pdf'.fz => :img,
  '.ico'.fz => :img,
}

CodeType = %w[
  .js javascript
  .rb ruby
  .c c
  .d d
  .yaml yaml
  .json json
  .py python
  .rs rust
  .hs haskell
  .mkdn markdown
  .txt unknown
  .sh shell
  .svg xml
  .xml xml
].each_slice(2).to_h
CodeType.default = 'plaintext'
CodeType.fz

class ViewDecider
  def initialize app, guide=VIEW_GUIDE
    @app = app
    @guide = guide
  end

  def call env
    log_self

    path = env[REAL_PATH]
    
    env[VIEW] =
      if path.directory?
        if h=@guide[:/]
          h[env[QUERY]] || @guide[Dir]
        else
          @guide[Dir]
        end

      elsif path.file?

        if h=@guide[path.extname]
          h[env[QUERY]] || @guide[File]
        else
          @guide[File]
        end
        
      end
    
    @app.(env)
  end
end

VIEW_GUIDE[:/].default = DirPage
VIEW_GUIDE[:code].default = CodePage
VIEW_GUIDE['.mkdn'].default = PandocPage
VIEW_GUIDE['.txt'].default = TxtPage
VIEW_GUIDE[:img].default = RawPage
VIEW_GUIDE['.svg'].default = RawPage

VIEW_GUIDE.each do |k, v|
  if v.is_a? Symbol
    VIEW_GUIDE[k] = VIEW_GUIDE[v]
  end
  
  if :/ != k and v.is_a?(Hash)
    v['download'.fz] = DownloadPage
  end
end

class Render
  
  def self.call env
    log_self
    view = env[VIEW] || EmptyPage

    kw = {}
    view::KW.each do |k, v|
      kw[k] = env[v]
    end

    view.(env, **kw)
  end
end
