require 'strscan'
$KCODE="U"

class Integer
  def into(v); v << self end
  def into!(v); into(v) end
  def reset!; :nop end
  def reset; :nop end
end

module UdonParser
  def self.parse(str) Parser.new(str).parse end
  def self.parse_file(fname) Parser.new(IO.read(fname)).parse end


  class UArray < Array
    def into(v); into!(v) unless size == 0 end
    def into!(v); v << self end
    def reset!; self.clear end
    def reset; d=dup;d.reset!;d end
  end

  class UHash < Hash
    def into!(v) v << self end
    def into(v) v << self end
    def <<(kv) k,v = kv; self[k] = v end
    def reset!; self.clear end
    def reset; d=dup; d.reset!; d end
  end

  class UString < String
    def into(v); into!(v) unless size == 0 end
    def into!(v)
      v << self.dup
      reset!
    end

    def <<(v)
      begin; super([v].pack('U*'))
      rescue; super(v) end
    end
    def reset!; self.gsub! /./um,'' end
    def reset; d=dup;d.reset!;d end
  end

  class UNode
    attr_accessor :name, :m,:a,:c
    def initialize(params={})
      @m = params.delete(:m) || UHash.new
      @m[:sline] ||= params.delete(:sline)
      @m[:schr] ||= params.delete(:schr)
      @a= params.delete(:a) || UHash.new
      @c= params.delete(:c) || []
      @name = params.delete(:name)
    end
    def into!(val) val << self end
    def into(val) val << self end
    def <<(val) @c<<val end
    def [](key) @c[key] end
  end

  class Parser < StringScanner
    def init(source, opts={})
      opts ||= {}
      super ensure_encoding(source)
      @global = {}
    end

    def ensure_encoding(source)
      if defined?(::Encoding)
        if source.encoding == ::Encoding::ASCII_8BIT
          b = source[0, 4].bytes.to_a
          source =
            case
            when b.size>=4 && b[0]==0 && b[1]==0 && b[2]==0
              source.dup.force_encoding(::Encoding::UTF_32BE).encode!(::Encoding::UTF_8)
            when b.size>=4 && b[0]==0 && b[2]==0
              source.dup.force_encoding(::Encoding::UTF_16BE).encode!(::Encoding::UTF_8)
            when b.size>=4 && b[1]==0 && b[2]==0 && b[3]==0
              source.dup.force_encoding(::Encoding::UTF_32LE).encode!(::Encoding::UTF_8)
            when b.size>=4 && b[1]==0 && b[3]==0
              source.dup.force_encoding(::Encoding::UTF_16LE).encode!(::Encoding::UTF_8)
            else source.dup end
        else source = source.encode(::Encoding::UTF_8) end
        source.force_encoding(::Encoding::ASCII_8BIT)
      else
        b = source
        source =
          case
          when b.size >= 4 && b[0] == 0 && b[1] == 0 && b[2] == 0; Iconv.iconv('utf-8', 'utf-32be', b)
          when b.size >= 4 && b[0] == 0 && b[2] == 0; Iconv.iconv('utf-8', 'utf-16be', b)
          when b.size >= 4 && b[1] == 0 && b[2] == 0 && b[3] == 0; Iconv.iconv('utf-8', 'utf-32le', b)
          when b.size >= 4 && b[1] == 0 && b[3] == 0; Iconv.iconv('utf-8', 'utf-16le', b)
          else b end
      end
      return source
    end

    def parse
      reset
      @line = 1
      @pos = 1
      @leading = true
      @indent = 0
      @ast = document
      return @ast
    end

    private

    def error(msg)
      $stderr.puts "#{msg} | line: #{@line} | char: #{@pos}"
    end

    def global_state(c)
      # Unicode newline characters & combinations
      # Plus leading space for indents.
      # Also tracks line and position for the AST
      @last_is_newline = @last_is_space = false
      case c
      when 0x0b, 0x0c, 0x85, 0x2028, 0x2029
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x0a
        nc = peek(4).unpack('U')[0]
        if nc == 0x0d then getch; c = UString.new("\n\r") end
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x0d
        nc = peek(4).unpack('U')[0]
        if nc == 0x0a then getch; c = UString.new("\r\n") end
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x20,0x09
        @indent += 1 if @leading
        @last_is_space = true; @pos += 1
      else @leading = false; @pos += 1 end
      return @last_c = c
    end

    def nl?() return @last_is_newline end
    def space?() return @last_is_space end

    def nextchar
      if @fwd then @fwd = false; return @last_c
      else
        c = getch
        if c.nil?
          c = :eof
          @last_is_space = @last_is_newline = false
          return @last_c = c
        end
        return global_state(c.unpack('U')[0])
      end
    end

    def eof?() return @last_c == :eof end

    def document(p=nil,name=UString.new('document'))
      __state=':data_or_child'
      s = UArray.new
      a ||= UString.new
      b ||= UString.new
      loop do
        __i = nextchar
        __state = '{eof}' if __i==:eof
        case __state
        when ':data_or_child'
            case
            when nl?; @fwd=true; b.into(a); __state=':data'; next
            when __i==9,space?; __i.into(b); next
            when __i==35,__i==124; @fwd=true; b.reset!; a.into(s); __state=':child'; next
            else @fwd=true; b.into(a); __state=':data'; next
            end
        when ':child'
            case
            when __i==35; __state=comment(':data_or_child',s); next
            when __i==124; __state=node(':data_or_child',s); next
            end
        when '{eof}'
            @fwd=true; b.into(a); a.into(s); return(s)
        when ':data'
            case
            when nl?; __i.into(a); a.into(s); __state=':data_or_child'; next
            else __i.into(a); next
            end
        end
        error("Unexpected #{__i}")
        @fwd = true
        return
      end
    end

    def comment(ns,p=nil,name=UString.new('comment'))
      ibase=@indent+1
      ipar=@indent
      __state=':first:ws'
      s = UNode.new(:name=>name,:sline=>@line,:schr=>@pos)
      a ||= UString.new
      loop do
        __i = nextchar
        __state = '{eof}' if __i==:eof
        case __state
        when ':first:ws'
            case
            when __i==9,space?; ibase += 1; next
            when nl?; __state=':nl'; next
            else __i.into(a); __state=':data'; next
            end
        when ':nl'
            case
            when (@indent>ibase); @fwd=true; __state=':data'; next
            when __i==9,space?; next
            when nl?; __i.into(a); a.into(s); next
            when (@indent<=ipar); @fwd=true; s.into(p); return(ns)
            else __i.into(a); ibase=@indent; __state=':data'; next
            end
        when '{eof}'
            @fwd=true; a.into(s); s.into(p); return(ns)
        when ':data'
            case
            when nl?; a.into(s); __state=':nl'; next
            else __i.into(a); next
            end
        end
      end
    end

    def node(ns,p=nil,name=UString.new('node'))
      ipar=@indent
      __state=':ident'
      s = UNode.new(:name=>name,:sline=>@line,:schr=>@pos)
      a ||= UString.new
      loop do
        __i = nextchar
        case __state
        when ':ident:child:nl'
            if !eof?
              @fwd=true; error('nyi'); return(ns)
            end
        when ':ident:child'
            case
            when (eof?); @fwd=true; a.into(s); return(ns)
            when nl?; __i.into(a); a.into(s); __state=':ident:child:nl'; next
            when !eof?; __i.into(a); next
            end
        when ':ident:a_or_c'
            case
            when (eof?); @fwd=true; a.into(s.c.last); return(ns)
            when __i==58; a.reset!; s.c.pop.into(aname); __state=':ident:attr:val'; next
            when __i==9,space?; __i.into(a); next
            when nl?; __i.into(a); a.into(s.c.last); __state=':ident:nl'; next
            when !eof?; __i.into(a); __state=':ident:child'; next
            end
        when ':ident'
            case
            when __i==9,space?; __state=':ident:nxt'; next
            when nl?; __state=':ident:nl'; next
            when (__i>45&&__i<48),__i==123; @fwd=true; __state=':ident:nxt'; next
            when !eof?; @fwd=true; __state=cstr(':ident:nameret',s); next
            end
        when ':ident:attr:val'
            if !eof?
              @fwd=true; error('nyi'); return(ns)
            end
        when ':ident:nxt'
            case
            when (__i>45&&__i<48),__i==123; error('nyi'); return(ns)
            when nl?; __state=':ident:nl'; next
            when __i==9,space?; next
            when !eof?; @fwd=true; __state=cstr(':ident:a_or_c',s); next
            end
        when ':ident:nameret'
            @fwd=true; s.name.reset!; s.c.pop.into(s.name); __state=':ident:nxt'; next
        when ':ident:nl'
            case
            when __i==9,space?; next
            when nl?; next
            when (@indent<=ipar); @fwd=true; s.into(p); return(ns)
            when !eof?; @fwd=true; ibase=@indent; __state=':ident:nxt'; next
            end
        end
        error("Unexpected #{__i}")
        @fwd = true
        return
      end
    end

    def cstr(ns,p=nil,name=UString.new('cstr'))
      __state=':first'
      s = UArray.new
      a ||= UString.new
      loop do
        __i = nextchar
        case __state
        when ':first'
            case
            when (eof?); @fwd=true; a.into!(p); return(ns)
            when __i==34; __state=':dq-dat'; next
            when __i==39; __state=':sq-dat'; next
            when __i==96; __state=':bt-dat'; next
            when nl?,(__i>8&&__i<11),space?; @fwd=true; a.into!(p); return(ns)
            when !eof?; __i.into(a); __state=':dat'; next
            end
        when ':dat'
            case
            when (eof?); @fwd=true; a.into!(p); return(ns)
            when nl?,(__i>8&&__i<11),space?; @fwd=true; a.into!(p); return(ns)
            when !eof?; __i.into(a); next
            end
        end
        error("Unexpected #{__i}")
        @fwd = true
        return
      end
    end

  end
end
