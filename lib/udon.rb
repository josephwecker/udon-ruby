module Udon
  require 'udon/udon_parser'
  VERSION = File.exist?(File.join(File.dirname(__FILE__),'VERSION')) ? File.read(File.join(File.dirname(__FILE__),'VERSION')) : ""
  class << self
    def version() VERSION end

    def parse(source, opts={})
      pp_ast = opts.delete(:pp_ast) || false
      res = UdonParser::Parser.new(source, opts).parse
      if pp_ast
        require 'pp'
        puts "\n----------------- AST ---------------------"
        pp res
        puts "\n-------------------------------------------"
      end
      return res
    end
  end
end
