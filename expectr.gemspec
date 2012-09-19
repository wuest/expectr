$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'expectr/version'

Gem::Specification.new do |s|
  s.name = "expectr"
  s.version = Expectr::VERSION

  s.description = "Expectr is an interface to the functionality of Expect in Ruby"
  s.summary = "Expect for Ruby"
  s.authors = ["Chris Wuest"]
  s.email = "chris@chriswuest.com"
  s.homepage = "http://github.com/cwuest/expectr"

  s.files = `git ls-files`.split("\n")
	s.test_files = s.files.select { |f| f =~ /^test\/test_/ }

  s.license = 'MIT'
end
