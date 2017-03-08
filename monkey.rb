
require 'pathname'
require 'set'

class Object
  def each_self
    Enumerator.new do |yeeld| yeeld << self end
  end

  alias fz freeze

  def log_self
    # Thin::Logging.log_info(self.is_a?(Class) ? self.to_s : self.class.to_s) 
  end
end

class Hash
  def to_proc; method(:[]).to_proc end
  alias call []
end

class Proc
  def flatsplat level=nil
    proc do |*args|
      self.(*(args.flatten(level)))
    end
  end
  def flip
    proc do |arg1, arg2, *args|
      self.(arg2, arg1, *args)
    end
  end
  def procarg0
    proc do |arg0, *args|
      self.(arg0, *args)
      arg0
    end
  end
end

class Set
  def when; method(:member?) end
end

class Array
  def when
    proc do |other|
      other.is_a?(Array) &&
        other.length == self.length &&
          self.lazy.zip(other).all?(&:===.to_proc.flatsplat(1))
    end
  end
  def oneOf
    proc do |other|
      self.any?(&:===.to_proc.flip.curry(2).(other))
    end
  end
end

class String
  def to_p
    Pathname.new(self)
  end
  def to_attr
    encode(xml: :attr)
  end
  def to_xml
    encode(xml: :text)
  end
  alias each each_self
end

class Pathname
  ROOT = '/'.fz.to_p
  alias rel_from relative_path_from
  def unroot
    if self.absolute?
      self.rel_from(ROOT)
    end
  end
  def to_p
    self
  end
end

class Time
  def to_ms
    to_r.numerator/1000000
  end
end
