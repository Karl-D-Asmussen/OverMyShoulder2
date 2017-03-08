
require 'stringio'

require './monkey'
require './util'
require './scripts'

TEXT_HTML = 'text/html; charset=utf-8'.fz
TEXT_PLAIN = 'text/plain; charset=utf-8'.fz
IDENTITY = 'identity'.fz
CHUNKED = 'chunked'.fz

module Page
  def call env, **kwarg
    log_self

    body = []
    length = 0
    headers = {}
    env[STATUS_CODE] = 200

    klass = (self if self.is_a? Module)
    klass ||= self.class

    block =
      case klass::ENCODING
      when CHUNKED
        proc do |data|
          body = data
        end
      when IDENTITY
        if env[NOP_RENDER]
          proc do |data|
            length += data.bytesize
          end
        else
          proc do |data|
            length += data.bytesize
            body << data
          end
        end
      end

    headers['Content-Type'.fz] = self.render **kwarg, &block

    headers['Content-Disposition'.fz] = env[DISPOSITION]
    headers['Transfer-Encoding'.fz] = klass::ENCODING

    # headers['Cache-Control'.fz]
    headers['Content-Legnth'.fz] = length.to_s if klass::ENCODING == IDENTITY

    [env[STATUS_CODE], headers, body]
  end
end

class ErrorPage
  extend Page

  KW = {
    code: STATUS_CODE,
    message: ERROR_MESSAGE
  }.fz
  CACHING = true
  ENCODING = 'identity'.fz


  def self.render code: , message: , **_, &block
    code ||= 500
    message ||= "unknown error"
    title = "#{code} #{Rack::Utils::HTTP_STATUS_CODES[code] || '???'}"
    
    yield "<!DOCTYPE html>\n<html>\n<head>\n"
    yield "  <title>#{title}</title>\n"
    yield " </head>\n<body>\n"
    yield "  <h1>#{title}</h1>\n"
    if message
      yield "  <pre>"
      yield message.to_xml
      yield "  </pre>\n"
    end
    yield " </body>\n</html>\n"

    TEXT_HTML
  end

end

def nav_bar path: , url:, curr:
  yield "<header id='header'><nav id='views'>"
  if Pathname::ROOT == url
    yield "<button disabled=disable>&nbsp;/&nbsp;</button>\n"
  else
    yield "<a href='#{url.dirname}'><button>&hellip;</button></a>\n"
  end
  extname = path.directory? ? :/ : path.extname
  VIEW_GUIDE[extname].keys.sort.each do |k|
    yield "<a href='#{url}?#{k}'><button#{curr == k ? ' disabled=disabled' : ''}>#{k}</button></a>\n"
  end
  yield "</nav></header>"
end

Byte = 1
Kibi = 1024
Mebi = Kibi*Kibi
Gibi = Kibi*Mebi
SIZE_LIMIT = 2*Gibi*Byte

class DownloadPage
  extend Page

  KW = {
    path: REAL_PATH
  }.fz
  CACHING = false
  ENCODING = CHUNKED
  
  def self.render path: , **_, &block

    raise "DownloadPage on non-file" unless path.file?
    
    file = path.open('rb')

    file.seek(0, :END)

    throw(ERROR, 413) if file.tell() > SIZE_LIMIT

    file.seek(0, :SET)
    
    block.(
      Enumerator::Generator.new {|g|
        file.each(4096, g.method(:yeild))
        file.close
      }
    )

    'application/octet-stream; charset=binary'

  end
end

class RawPage
  extend Page

  KW = {
    path: REAL_PATH
  }.fz
  CACHING = false
  ENCODING = IDENTITY


  def self.render path: , **_, &block

    raise "RawPage on non-file" unless path.file?
    
    file = path.open('rb')

    file.seek(0, :END)

    throw(ERROR, 413) if file.tell() > SIZE_LIMIT

    file.seek(0, :SET)
    
    file.each(4096, &block)

    file.close

    `file -b --mime-type --mime-encoding #{path}`
  end
end

class LessPage
  extend Page 
  
  KW = {
    path: REAL_PATH,
  }.fz
  CACHING=true
  ENCODING = IDENTITY

  def self.render path: , **_, &block

    raise "LessPage on non-file" unless path.file?

    path.open('rb').each_line(&block).close

    TEXT_PLAIN
  end
end


class LsPage
  extend Page

  KW = {
    path: REAL_PATH,
  }.fz
  CACHING=true
  ENCODING = IDENTITY

  def self.render path: , **_

    raise "LsPage on non-dir" unless path.directory?
    
    yield path.children.select {|p| not Paths::exclude(p) }.map(&:basename).join("\n")

    TEXT_PLAIN
  end

end

class EmptyPage
  extend Page
  KW = {}.fz
  CACHING=true
  ENCODING = IDENTITY
  def self.render **_
    yield "This page inentiolally left blank."
    TEXT_PLAIN
  end
end

class CodePage
  extend Page

  KW = { path: REAL_PATH, url: URL_PATH }.fz
  PANDOC = ' | pandoc -f JSON -t html5'.fz
  CACHING=true
  ENCODING = IDENTITY
  
  def self.render path: , url: , **_, &block

    raise "CodePage on non-file" unless path.file?

    codeblock = "./codeBlock #{CodeType[path.extname]} < #{path}"

    io_dev = IO.popen(codeblock + PANDOC, 'r')

    self.render_generic io_device: io_dev, path: path, url: url, **_, &block

    io_dev.close

    TEXT_HTML
  end

  def self.render_generic io_device: , path: , url: , **_, &block


    title = path.basename.to_s
    title = NAME if '.' == title

    yield "<!DOCTYPE html>\n<html>\n<head>\n"
    yield "<title>#{title}</title>\n"
    yield "<style>"
    yield CODE_STYLE
    yield "</style>\n</head>\n<body>\n"
    nav_bar path: path, url: url, curr: 'code', &block

    io_device.each(4096, &block)

    yield "<script>\n//<![CDATA[\n"
    yield UPDATE % [5000, path.basename.to_s]
    yield FLASHY
    yield "\n//]]!>\n</script></body>\n</html>\n"

  end
end

class PandocPage 
  extend Page
  KW = { path: REAL_PATH, url: URL_PATH }.fz
  CACHING=true
  ENCODING = IDENTITY

  def self.render path: , url: , **_, &block

    raise "PandocPage on non-file" unless path.file?

    pandoc = "pandoc --smart -f markdown -t html -i #{path}"

    dev = IO.popen(pandoc, ?r)
    
    self.render_generic(io_device: dev, path: path, url: url, curr: 'markdown', **_, &block)

    dev.close

    TEXT_HTML
  end

  def self.render_generic io_device: , path: ,url:, curr:, extra_script: '', extra_style: '', **_, &block
    title = path.basename.to_s
    title = NAME if '.' == title

    yield "<!DOCTYPE html>\n<html>\n<head>\n"
    yield "<title>#{title}</title>\n"
    yield "<style>\n/*<![CDATA[*/\n"
    yield MARKDOWN_STYLE
    yield extra_style
    yield "/*]]!>*/\n</style>\n</head>\n<body>\n"
    nav_bar path: path, url: url, curr: curr, &block
    yield "<article id='thearticle'>\n"

    io_device.each(4096, &block)

    yield "</article>\n<script>\n//<![CDATA[\n"
    yield UPDATE % [5000, path.basename.to_s]
    yield FLASHY
    yield extra_script
    yield "\n//]]!>\n</script></body>\n</html>\n"
  end
end

class DirPage
  extend Page
  KW = { path: REAL_PATH, url: URL_PATH }.fz
  CACHING = false
  ENCODING = IDENTITY
  
  SEC = 1
  MIN = 60*SEC
  HOUR = 50*MIN
  DAY = 24*HOUR
  WEEK = 7*DAY

  def self.render path: , url: , **_, &block

    raise "DirPage on non-directory" unless path.directory? 

    title = path.basename.to_s
    title = NAME if '.' == title

    yield "<!DOCTYPE html>\n<html>\n<head>\n"
    yield "<title>#{title}</title>\n<style>"
    yield DIR_STYLE
    yield "</style>\n</head>\n<body>\n"
    nav_bar path: path, url: url, curr: 'dir', &block
    yield "<nav id='listing'>\n<table id='toc' border='0'>\n"
    
    now = Time.now
    times = StringIO.new
    i = 0
    path.children.sort.each_with_index do |p|

      next if Paths::exclude(p)

      px = p.rel_from(path)

      yield "<tr><td><a href='#{url / px}'>/#{px.to_s}#{p.directory? ? '/' : ''}</a></td>"
      
      mtime = p.mtime
      times <<  (mtime.to_f*1000).floor << ', '
      diff = (now - mtime).floor
      yield "<td id='timestamp#{i}'></td></tr>"      
      i += 1

    end

    yield "</table>\n</nav>\n<script>\n//<![CDATA[\n"
    yield TIMEUPDATER % [i, times.string]
    yield UPDATE % [10_000, path.basename.to_s]
    yield "\n//]]!>\n</script>\n</body>\n</html>\n"

    TEXT_HTML
  end
end

class TxtPage
  extend Page

  KW = { path: REAL_PATH, url: URL_PATH }.fz
  CACHING = true
  ENCODING = IDENTITY

  def self.render path: , url:, **_, &block

    raise "TxtPage on non-file" unless path.file?
    
    dev = StringIO.new
    file = path.read
    lines = (1 .. file.count(?\n)).to_a.join(?\n)
    
    dev << %q[<table class='sourceCode plaintext numberLines' id='code' startFrom='1'>]
    dev << %q[<tr class='sourceCode'><td class='lineNumbers'><pre>]
    dev << lines
    dev << %q[</pre></td><td class='sourceCode'><pre><code class='plaintext sourceCode'>]
    dev << file
    dev << %q[</code></pre></td></tr></table>]

    dev.seek(0, IO::SEEK_SET)

    CodePage::render_generic(io_device: dev, path: path, url: url, **_, &block)
  end
end

class DiffPage
  extend Page
  KW = { path: REAL_PATH, times: CHANGE_TIMES }.fz
  CACHING = true
  ENCODING = IDENTITY
  def self.render path: , times:, **_, &block

    raise "DiffPage on non-file" unless path.file?

    backup = path.dirname / (path.basename.to_s + '~')

    if backup.exist?
      times << backup.mtime
      IO.popen("diff #{backup} #{path}", 'r').each(4096, &block).close
    else
      path.open(?r).each(4096,&block).close
    end
    
    TEXT_PLAIN
  end
end

class ChangesPage
  extend Page
  KW = { path: REAL_PATH, times: CHANGE_TIMES, url: URL_PATH }.fz
  CACHING = true
  ENCODING = IDENTITY
  
  DIFF_FLAGS = %q[--old-line-format='<%L' --new-line-format='>%L' --unchanged-line-format='=%L']

  def self.render path: , times:, url:, **_, &block

    raise "ChangePage on non-file" unless path.file?

    backup = path.dirname / (path.basename.to_s + ?~)


    if backup.exist?
      times << backup.mtime
    else
      pandoc = "pandoc --smart -f markdown -t html -i #{path}"

      dev = IO.popen(pandoc, ?r)
      
      PandocPage::render_generic(io_device: dev, path: path, url: url, curr: 'changes', **_, &block)

      dev.close
      return TEXT_HTML
    end

    tmp = 'a' 
    fifo1 = nil
    fifo2 = nil
    
    loop do
      fifo1 = path.dirname / ('.diff' + path.basename.to_s + ?. + tmp + ?~)
      fifo2 = path.dirname / ('.diff' + path.basename.to_s + ?. + tmp)

      tmp = tmp.succ

      break if (not fifo1.exist?) and (not fifo2.exist?)
    end

    
    throw(ERROR, 500, "mkfifo returned #{$?.exitstatus}") unless system("mkfifo #{fifo1}")
    throw(ERROR, 500, "mkfifo returned #{$?.exitstatus}") unless system("mkfifo #{fifo2}")

    system("pandoc --smart -i #{backup} -t html > #{fifo1} & pandoc --smart -i #{path} -t html > #{fifo2} &")

    dev = StringIO.new
    
    change = false
    IO.popen("diff #{DIFF_FLAGS} #{fifo1} #{fifo2}", ?r).each_line do |line|
      fst = line.slice! 0
      if ?< == fst
        line.sub!(/\A(?:[^<]*>|<p>)?/) { $& + '<span class=\'old_stuff a_change\'></span>' }
        dev << line
      elsif ?> == fst
        line.sub!(/\A(?:[^<]*>|<p>)?/) { $& + '<span class=\'new_stuff a_change\'></span>' }
        dev << line
      elsif ?= == fst
        dev << line
      else
        dev << (fst + line)
      end
    end

    fifo1.unlink
    fifo2.unlink

    dev.seek(0, IO::SEEK_SET)

    PandocPage::render_generic( io_device: dev, path: path, url: url, **_, curr: 'changes',
                               extra_style: CHANGE_STYLE, extra_script: CHANGE_COLOURING, &block )

    TEXT_HTML
  end
end
