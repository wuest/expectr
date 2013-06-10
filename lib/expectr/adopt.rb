require 'expectr'
require 'expectr/interface'
require 'expectr/child'

class Expectr
  # Internal: The Expectr::Adopt Class contains the interface to interacting
  # with child processes not spawned by Expectr.
  #
  # All methods with the prefix 'interface_' in their name will return a Proc
  # designed to be defined as an instance method in the primary Expectr object.
  # These methods will all be documented as if they are the Proc in question.
  class Adopt < Expectr::Child
    # Public: Initialize a new Expectr::Adopt object.
    # IO Objects are named in such a way as to maintain interoperability with
    # the methods from the Expectr::Child class.
    #
    # stdin  - IO object open for writing.
    # stdout - IO object open for reading.
    # pid    - FixNum corresponding to the PID of the process being adopted
    #          (default: 1)
    def initialize(stdin, stdout)
      unless stdin.kind_of?(IO) && stdout.kind_of?(IO)
        raise(TypeError, "Arguments of type IO expected")
      end
      @stdin = stdin
      @stdout = stdout
      @stdout.winsize = $stdout.winsize if $stdout.tty?
    end

    # Public: Present a streamlined interface to create a new Expectr instance.
    #
    # stdout - IO object open for reading.
    # stdin  - IO object open for writing.
    # pid    - FixNum corresponding to the PID of the process being adopted
    #          (default: 1)
    # args   - A Hash used to specify options for the new object, per
    #          Expectr#initialize.
    #
    # Returns a new Expectr object
    def self.spawn(stdout, stdin, pid = 1, args = {})
      args[:interface] = :adopt
      args[:stdin] = stdin
      args[:stdout] = stdout
      args[:pid] = pid
      Expectr.new('', args)
    end
  end
end
