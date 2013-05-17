require 'pty'
require 'expectr/interface'

class Expectr
  # Internal: The Expectr::Child class contains the interface to interacting
  # with child processes.
  #
  # All methods with the prefix 'interface_' in their name will return a Proc
  # designed to be defined as an instance method in the primary Expectr object.
  # These methods will all be documented as if they are the Proc in question.
  class Child
    include Expectr::Interface
    attr_reader :stdin
    attr_reader :stdout
    attr_reader :pid

    # Public: Initialize a new Expectr::Child object.
    # Spawns a sub-process and attaches to STDIN and STDOUT for the new
    # process.
    #
    # cmd - A String or File referencing the application to launch.
    def initialize(cmd)
      cmd = cmd.path if cmd.kind_of?(File)
      unless cmd.kind_of?(String)
        raise(ArgumentError, "String or File expected")
      end

      @stdout,@stdin,@pid = PTY.spawn(cmd)
      @stdout.winsize = $stdout.winsize if $stdout.tty?
    end

    # Public: Send a signal to the running child process.
    #
    # signal - Symbol, String or FixNum corresponding to the symbol to be sent
    # to the running process. (default: :TERM)
    #
    # Returns a boolean indicating whether the process was successfully sent
    # the signal.
    # Raises ProcessError if the process is not running (@pid = 0).
    def interface_kill!
      ->(signal = :TERM) {
        raise ProcessError unless @pid > 0
        Process::kill(signal.to_sym, @pid) == 1
      }
    end

    # Public: Send input to the active child process.
    #
    # str - String to be sent.
    #
    # Returns nothing.
    # Raises Expectr::ProcessError if the process is not running (@pid = 0)
    def interface_send
      ->(str) {
        begin
          @stdin.syswrite str
        rescue Errno::EIO #Application is not running
          @pid = 0
        end
        unless @pid > 0
          raise(Expectr::ProcessError, "Child process no longer exists")
        end
      }
    end

    # Public: Read the child process's output, force UTF-8 encoding, then
    # append to the internal buffer and print to $stdout if appropriate.
    #
    # Returns nothing.
    def interface_output_loop
      -> {
        while @pid > 0
          unless select([@stdout], nil, nil, @timeout).nil?
            buf = ''

            begin
              @stdout.sysread(@buffer_size, buf)
            rescue Errno::EIO #Application is not running
              @pid = 0
              return
            end
            process_output(buf)
          end
        end
      }
    end

    def interface_interact_thread
      -> {
        Thread.new do
          env = prepare_interact_environment
          input = ''

          while @pid > 0 && @interact
            if select([$stdin], nil, nil, 1)
              c = $stdin.getc.chr
              send c unless c.nil?
            end
          end

          restore_environment(env)
        end
      }
    end
  end
end
