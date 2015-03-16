$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'expectr/version'

Gem::Specification.new do |s|
  s.name = "expectr"
  s.version = Expectr::VERSION

  s.description = "Expectr is an interface to the functionality of Expect in Ruby"
  s.summary = "Expect for Ruby"
  s.authors = ["Tina Wuest"]
  s.email = "tina@wuest.me"
  s.homepage = "http://github.com/wuest/expectr"

  s.files = `git ls-files lib`.split("\n")
  s.files += `git ls-files bin`.split("\n")

  s.executables = ['expectr']

  s.license = 'MIT'
end
