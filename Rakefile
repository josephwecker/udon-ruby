# encoding: utf-8

require 'rdoc/task'
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

file "lib/udon/udon_parser.rb" => ["machines/udon.machine"] do |t|
  sh "genmachine -o lib/udon/ -l ruby --no-executable -c UdonParser #{t.prerequisites.join(' ')}"
end
task :install => [:build_parser]

task :build_parser do |t|
  sh "rm -f lib/udon/udon_parser.rb"
  Rake::Task['lib/udon/udon_parser.rb'].execute
end

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "udon"
  gem.homepage = "http://udon.io"
  gem.license = "MIT"
  gem.summary = %Q{Universal Document and Object Notation}
  gem.description = %Q{Parse and generate udon, inspired by zml, haml, json, and more.}
  gem.email = "joseph.wecker@gmail.com"
  gem.authors = ["Joseph Wecker"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = false
end

task :test => ['lib/udon/udon_parser.rb']

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = false
  test.rcov_opts << '--exclude "gems/*"'
end

require 'reek/rake/task'
Reek::Rake::Task.new do |t|
  t.fail_on_error = true
  t.verbose = false
  t.source_files = 'lib/**/*.rb'
end

require 'roodi'
require 'roodi_task'
RoodiTask.new do |t|
  t.verbose = false
end

task :default => :test

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "udon #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
