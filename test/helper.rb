$KCODE = 'U'
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'iconv'
require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'udon'

class String
  def udon; Udon.parse(self) end
  def udon_pp; Udon.parse(self, :pp_ast=>true) end
end

class Array
  def gcd; inject(){|n1,n2| n1.gcd(n2)} end
end

class MiniTest::Unit::TestCase
  def gaussian(mean, stddev)
    theta = 2 * Math::PI * rand
    rho = Math.sqrt(-2 * Math.log(1 - rand))
    scale = stddev * rho
    if rand >= 0.5
      return mean + scale * Math.cos(theta)
    else
      return mean + scale * Math.sin(theta)
    end
  end

  def randstr(avg_length, char_dists = nil)
    char_dists ||= [[0.10,  " \t"],
                    [0.05,  "\n\r"],
                    [0.40,  ('a'..'z')],
                    [0.15,  ('A'..'Z')],
                    [0.15,  ('0'..'9')],
                    [0.075, (32..126)],
                    [0.05,  (0..255)],
                    [0.025, (0..0xffff)]]
    ret = ''
    char_dists = char_dists.scan /./umn if char_dists.is_a?(String)
    chrs = char_dists.sort_by{|n|n[0]}
    chrs.map! do |k,ch|
      if ch.nil?
        ch = k
        k = 1.0 / chrs.size.to_f
      end
      if ch.is_a?(Range)
        if ch.max.is_a?(String)
          [k, ((ch.min.unpack('U')[0])..(ch.max.unpack('U')[0]))]
        else [k, ch] end
      elsif ch.is_a?(Integer)
        [k, (ch..ch)]
      elsif ch.is_a?(String) && ch.scan(/./u).length == 1
        [k, ((ch.unpack('U')[0])..(ch.unpack('U')[0]))]
      elsif ch.is_a?(String)
        [k, ch.unpack('U*')]
      else
        raise ArgumentError, 'Ranges and strings only'
      end
    end
    len = [gaussian(avg_length,avg_length/2.0).round, 0].max
    (0..len).each do
      range_sel = rand
      prob_sum = 0.0
      chrs.each do |prob,cr|
        prob_sum += prob
        if prob_sum > range_sel
          if cr.is_a?(Range)
            ret << [(cr.min + rand(cr.max - cr.min + 1))].pack('U')
          else
            ret << cr[rand(cr.length)]
          end
          break
        end
      end
    end
    return fix_utf8(ret)
  end

  def fix_utf8(str)
    # (To fix iconv bug: cr http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/ )
    str = str + ' '
    Iconv.iconv('UTF-8//IGNORE', 'UTF-8', str)
    return str[0..-2]
  end

  def udon_safe(str)
    str.gsub! /^(\s*)(#|\|)/u, '\\1\\\\\2'
    str.gsub! /(\||!)\{/u, '\\1{{'
    str + "\n"
  end

  def rand_cstring(len=10)
    delim =(rand(2)==1 ? true : false)
    if delim
      rand_delimited_cstring(len)
    else
      rand_undelimited_cstring(len)
    end
  end

  def rand_delimited_cstring(len,left='(',right=')')
    name = randstr(len).scan(/./u)
    # Escape existing delimiters
    name = name.reduce([]) do |acc,chr|
      if chr == left || chr == right
        if acc.last == '\\' && acc[-2] == '\\'
          acc + [' ','\\',chr]
        elsif acc.last == '\\'
          acc + [chr]
        else
          acc + ['\\',chr]
        end
      else acc + [chr] end
    end
    # Inject some balanced parenthases
    (0..rand((len/5).round)).each do
      pos1 = rand(name.size)
      pos2 = rand(name.size - pos1) + pos1 + 1
      unless (name[pos1-1]=="\\" && name[pos1-2] !='\\') || (name[pos2-1]=="\\" && name[pos2-2] !='\\')
        name = name.insert(pos2,right).insert(pos1,left)
      end
    end
    name << ' ' if name.last=='\\'
    left + name.join('') + right
  end

  def unescaped_cstr(str,left='(',right=')')
    str = str.dup[1..-2] # Take off beginning and end delimiters
    for d in [left, right] do
      str = str.scan(/./u)
      str = str.reduce([]) do |acc,chr|
        if chr == d && (acc[-1]=='\\')
          acc.pop
          acc + [chr]
        else acc + [chr] end
      end
      str = str.join('')
    end
    return str
  end

  def rand_undelimited_cstring(len)
    name = randstr(len).unpack("U*")
    name = name - [0x0b, 0x0c, 0x85, 0x2028, 0x2029, 0x0a, 0x0d] # No newlines
    name = name - [0x20, 0x09]                                   # No spaces
    name = name - '[|.'.unpack("U*")                             # No [ or |
    name << '-'[0] if name.last == '\\'[0]                       # Make sure it doesn't end with a \
    name.unshift('-'[0]) if name.first == '{'[0]                 # Make sure it doesn't start with a {
    name.unshift('-'[0]) if name.first == '('[0]                 # Make sure it doesn't start with a (
    name = name.pack("U*")
    name = 'node' if name.length == 0                            # Make sure it is not blank
    name
  end
end

MiniTest::Unit.autorun
