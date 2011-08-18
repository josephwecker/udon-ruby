module Udon
  require 'udon/udon_parser'
  VERSION = File.exist?(File.join(File.dirname(__FILE__),'VERSION')) ? File.read(File.join(File.dirname(__FILE__),'VERSION')) : ""
  class << self
    def version() VERSION end

    def parse(source, opts={})
      res = UdonParser::Parser.new(source, opts).parse
      require 'pp'
      puts "\n----------------- AST ---------------------"
      pp res
      puts "\n-------------------------------------------"
      return res
    end
  end
end
