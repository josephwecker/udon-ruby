require 'strscan'
$KCODE="U"

module UdonParser
  def self.parse(str) Parser.new(str).parse end
  def self.parse_file(fname) Parser.new(IO.read(fname)).parse end

  class UHash < Hash
    def <<(kv) k,v = kv; self[k] = v end
  end

  class UString < String
    def <<(v)
      begin
        super([v].pack('U*'))
      rescue
        super(v)
      end
    end
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
        if nc == 0x0d then getch; c = "\n\r" end
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x0d
        nc = peek(4).unpack('U')[0]
        if nc == 0x0a then getch; c = "\r\n" end
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x20
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

    def document(p=nil,name='document')
      state=':data_or_child'
      s = []
      a ||= UString.new
      b ||= UString.new
      trash ||= UString.new
      loop do
        c = nextchar
        state = '{eof}' if c==:eof
        case state
        when ':data_or_child'
            case
            when nl?; @fwd=true; (a<<b if b.size>0); b=UString.new; state=':data'; next
            when space?; b<<c; next
            when c==35,c==124; @fwd=true; (trash<<b if b.size>0); b=UString.new; state=':child'; next
            else @fwd=true; (a<<b if b.size>0); b=UString.new; state=':data'; next
            end
        when ':child'
            if c==35
              @fwd=true; (s<<a if a.size>0); a=UString.new; state=comment(':data_or_child',s); next
            end
        when '{eof}'
            @fwd=true; (a<<b if b.size>0); b=UString.new; (s<<a if a.size>0); a=UString.new; return(s)
        when ':data'
            case
            when nl?; a<<c; (s<<a if a.size>0); a=UString.new; state=':data_or_child'; next
            else a<<c; next
            end
        end
      end
    end

    def comment(ns,p=nil,name='comment')
      ipar=@indent
      ibase=ipar+100
      state=':1st:ws'
      s = UNode.new(:name=>name,:sline=>@line,:schr=>@pos)
      a ||= UString.new
      loop do
        c = nextchar
        state = '{eof}' if c==:eof
        case state
        when ':nl'
            case
            when (@indent>ibase); @fwd=true; state=':child'; next
            when nl?,(c>8&&c<11),space?; next
            when (@indent<=ipar); @fwd=true; p<<s; return(ns)
            else a<<c; ibase = @indent; state=':child'; next
            end
        when ':child'
            case
            when nl?; (s<<a if a.size>0); a=UString.new; state=':nl'; next
            else a<<c; next
            end
        when ':1st'
            case
            when nl?; (s<<a if a.size>0); a=UString.new; state=':nl'; next
            else a<<c; next
            end
        when '{eof}'
            @fwd=true; (s<<a if a.size>0); a=UString.new; p<<s; return(ns)
        when ':1st:ws'
            case
            when c==9,space?; next
            when nl?; state=':nl'; next
            else a<<c; state=':1st'; next
            end
        end
      end
    end

  end
end
