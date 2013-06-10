require 'expectr'
require 'expectr/interface'

class Expectr
  # Internal: The Expectr::Lambda Class contains the interface to interacting
  # with ruby objects transparently via lambdas in a manner consistent with
  # other Expectr interfaces.
  #
  # All methods with the prefix 'interface_' in their name will return a Proc
  # designed to be defined as an instance method in the primary Expectr object.
  # These methods will all be documented as if they are the Proc in question.
  class Lambda
    include Expectr::Interface
    attr_reader :reader
    attr_reader :writer

    # Public: Initialize a new Expectr::Lambda object.
    #
    # reader - Lambda which is meant to be interacted with as if it were
    #          analogous to STDIN for a child process.
    # writer - Lambda which is meant to be interacted with as if it were
    #          analogous to STDOUT for a child process.
    def initialize(reader, writer)
      unless reader.kind_of?(Proc) && writer.kind_of?(Proc)
        raise(TypeError, "Proc Objects expected for reader and writer")
      end

      @reader = reader
      @writer = writer
    end

    # Public: Present a streamlined interface to create a new Expectr instance.
    #
    # reader - Lambda which is meant to be interacted with as if it were
    #          analogous to STDIN for a child process.
    # writer - Lambda which is meant to be interacted with as if it were
    #          analogous to STDOUT for a child process.
    # args   - A Hash used to specify options for the new object, per
    #          Expectr#initialize.
    #
    # Returns a new Expectr object
    def self.spawn(reader, writer, args = {})
      args[:interface] = :lambda
      args[:reader] = reader
      args[:writer] = writer
      Expectr.new('', args)
    end

    # Public: Send input to the active child process.
    #
    # args - Arguments to pass to the reader interface.
    #
    # Returns nothing.
    def interface_send
      ->(args) {
        @reader.call(*args)
      }
    end

    # Public: Prepare the operating environment for interact mode, set the
    # interact flag to true.
    #
    # Returns a Hash containing old signal handlers and tty parameters.
    def interface_prepare_interact_environment
      -> {
        env = {sig: {}}

        # Save old tty settings and set up the new environment
        env[:tty] = `stty -g`
        `stty -icanon min 1 time 0 -echo`

        # SIGINT should be sent to the child as \C-c
        env[:sig]['INT'] = trap 'INT' do
          send "\C-c"
        end

        # SIGTSTP should be sent to the process as \C-z
        env[:sig]['TSTP'] = trap 'TSTP' do
          send "\C-z"
        end

        @interact = true
        env
      }
    end

    # Public: Create a Thread containing the loop which is responsible for
    # handling input from the user in interact mode.
    #
    # Returns a Thread containing the running loop.
    def interface_interact_thread
      -> {
        Thread.new do
          env = prepare_interact_environment
          input = ''

          while @interact
            if select([$stdin], nil, nil, 1)
              c = $stdin.getc.chr
              send c unless c.nil?
            end
          end

          restore_environment(env)
        end
      }
    end

    # Internal: Call the writer lambda, reading the output, forcing UTF-8 and
    # appending to the internal buffer and printing to $stdout if appropriate.
    #
    # Returns nothing.
    def interface_output_loop
      -> {
        buf = ''
        loop do
          buf.clear

          begin
            buf << @writer.call.to_s
          rescue Errno::EIO # Lambda is signaling that execution should end.
            return
          end
          process_output(buf)
        end
      }
    end
  end
end
