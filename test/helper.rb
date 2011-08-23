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
  len = [gaussian(avg_length,avg_length/3.0).round, 0].max
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

class MiniTest::Unit::TestCase
end

MiniTest::Unit.autorun
