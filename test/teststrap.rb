require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'riot'
require 'udon'
require 'poisson'

class String
  def udon
    Udon.parse(self)
  end
end

class Array
  def gcd; inject(){|n1,n2| n1.gcd(n2)} end
end

def poisson(mean)
  el = Math.exp(-mean); k = 0; p = 1
  begin
    k += 1
    p = p * rand
  end while p > el
  return k - 1
end

def randstr(avg_length, char_dists = [[0.1,' '],[0.1,('A'..'Z')],[0.8,('a'..'z')]])
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
    elsif ch.is_a?(String)
      [k, ((ch.unpack('U')[0])..(ch.unpack('U')[0]))]
    else
      raise ArgumentError, 'Ranges and strings only'
    end
  end
  (0..poisson(avg_length)).each do
    range_sel = rand
    prob_sum = 0.0
    chrs.each do |prob,cr|
      prob_sum += prob
      if prob_sum > range_sel
        ret << [(cr.min + rand(cr.max - cr.min + 1))].pack('U')
        break
      end
    end
  end
  return ret
end
