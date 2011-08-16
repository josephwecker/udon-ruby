require 'strscan'
$KCODE="U"

module UdonParser
  def self.parse(str) Parser.new(str).parse end
  def self.parse_file(fname) Parser.new(IO.read(fname)).parse end

  class Node
    attr_accessor :name, :children, :start_line, :start_pos, :end_line, :end_pos
    def initialize(name='node',line=:unknown,pos=:unknown)
      @name = name
      @children = []
      @start_line = line
      @start_pos = pos
      @end_line = :unknown
      @end_pos = :unknown
    end
    def <<(val) @children<<val end
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
          when b.size >= 4 && b[0] == 0 && b[1] == 0 && b[2] == 0; JSON.iconv('utf-8', 'utf-32be', b)
          when b.size >= 4 && b[0] == 0 && b[2] == 0; JSON.iconv('utf-8', 'utf-16be', b)
          when b.size >= 4 && b[1] == 0 && b[2] == 0 && b[3] == 0; JSON.iconv('utf-8', 'utf-32le', b)
          when b.size >= 4 && b[1] == 0 && b[3] == 0; JSON.iconv('utf-8', 'utf-16le', b)
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
        nc = peek(1).unpack('U')[0]
        if nc == 0x0d then getch; c = 0x0a0d end
        @last_is_newline = true; @line += 1; @pos = 1
        @leading = true; @indent = 0
      when 0x0d
        nc = peek(1).unpack('U')[0]
        if nc == 0x0a then getch; c = 0x0d0a end
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
      state=':ws'
      s = Node.new(name,@line,@pos)
      loop do
        c = nextchar
        case state
        when ':ws'
            case
            when (eof?); return(s)
            when nl?,(c>8&&c<11),space?; next
            else @fwd=true; state=':child'; next
            end
        when ':child'
            case
            when c==35; state=comment(':ws',s); next
            when c==124; state=node(':ws',s); next
            end
        end
        error("Unexpected #{c}")
        @fwd = true
        return
      end
    end

    def to_nextline(ns,p=nil,name='to_nextline')
      state=':scan'
      loop do
        c = nextchar
        case state
        when ':scan'
            case
            when (eof?); @fwd=true; return(ns)
            when nl?; @fwd=true; return(ns)
            when c!=':eof'; next
            end
        end
        error("Unexpected #{c}")
        @fwd = true
        return
      end
    end

    def comment(ns,p=nil,name='comment')
      ipar=@indent
      ibase=ipar+100
      state=':1st:ws'
      s = Node.new(name,@line,@pos)
      a ||= ''
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
            when nl?; (s<<a if a.size>0); a=''; state=':nl'; next
            else a<<c; next
            end
        when ':1st'
            case
            when nl?; (s<<a if a.size>0); a=''; state=':nl'; next
            else a<<c; next
            end
        when '{eof}'
            @fwd=true; (s<<a if a.size>0); a=''; p<<s; return(ns)
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
