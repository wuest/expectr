require 'expectr'
require 'expectr/interface'
require 'expectr/child'

class Expectr
  # Public: The Expectr::Adopt Module defines the interface for interacting
  # with child processes without spawning them through Expectr.
  module Adopt
    include Expectr::Child

    # Public: Initialize the Expectr interface, adopting IO objects to act on
    # them as if they were produced by spawning a child process.
    # IO Objects are named in such a way as to maintain interoperability with
    # the methods from the Expectr::Child module.
    #
    # args - Hash containing IO Objects and optionally a PID to watch.
    #        stdin  - IO object open for writing.
    #        stdout - IO object open for reading.
    #        pid    - FixNum corresponding to the PID of the process being
    #                 adopted. (default: 1)
    #
    # Returns nothing.
    # Raises TypeError if args[:stdin] or args[:stdout] aren't of type IO.
    def init_interface(args)
      unless args[:stdin].kind_of?(IO) && args[:stdout].kind_of?(IO)
        raise(TypeError, Errstr::IO_EXPECTED)
      end
      @stdin = args[:stdin]
      @stdout = args[:stdout]
      @stdout.winsize = $stdout.winsize if $stdout.tty?
      @pid = args[:pid] || 0

      if @pid > 0
        Thread.new do
          Process.wait @pid
          @pid = 0
        end
      end
    end

    # Public: Present a streamlined interface to create a new Expectr instance
    # using the Adopt interface.
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
      Expectr.new(args)
    end
  end
end
