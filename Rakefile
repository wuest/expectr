require 'rake/testtask'
require 'rdoc/task'

task default: :test

Rake::TestTask.new(:test) do |t|
	t.libs.unshift File.expand_path('../test', __FILE__)
  t.test_files = Dir.glob('test/**/test_*.rb')
	t.ruby_opts = ['-rubygems'] if defined? Gem
	t.ruby_opts << '-I./lib'
end

RDoc::Task.new(:doc) do |rdoc|
	rdoc.rdoc_dir = 'doc'
	rdoc.main = 'README.rdoc'
	rdoc.rdoc_files.include('README.rdoc', 'lib/*.rb')
	rdoc.options = %w[--inline-source --line-numbers --title Expectr --encoding=UTF-8 --main README.rdoc]
end
