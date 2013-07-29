require 'expectr'
require 'expectr/interface'

class Expectr
  # Public: The Expectr::Lambda Module defines the interface for interacting
  # with Proc objects in a manner which is similar to interacting with
  # processes.
  module Lambda
    include Expectr::Interface

    # Public: Initialize the Expectr Lambda interface.
    #
    # args - Hash containing Proc objects to act as reader and writer:
    #        reader - Lambda which is meant to be interacted with as if it were
    #                 analogous to STDIN for a child process.
    #        writer - Lambda which is meant to be interacted with as if it were
    #                 analogous to STDOUT for a child process.
    #
    # Raises TypeError if arguments aren't of type Proc.
    def init_interface(args)
      unless args[:reader].kind_of?(Proc) && args[:writer].kind_of?(Proc)
        raise(TypeError, Errstr::PROC_EXPECTED)
      end

      @pid = -1
      @reader = args[:reader]
      @writer = args[:writer]
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
      Expectr.new(args)
    end

    # Public: Send input to the reader Proc.
    #
    # args - Arguments to pass to the reader interface.
    #
    # Returns nothing.
    def send(args)
      @reader.call(*args)
    end

    # Public: Prepare the operating environment for interact mode, set the
    # interact flag to true.
    #
    # Returns a Hash containing old signal handlers and tty parameters.
    def prepare_interact_environment
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
    end

    # Public: Create a Thread containing the loop which is responsible for
    # handling input from the user in interact mode.
    #
    # Returns a Thread containing the running loop.
    def interact_thread
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
    end

    private

    # Internal: Call the writer lambda, reading the output produced, forcing
    # UTF-8, appending to the internal buffer and printing to $stdout if
    # appropriate.
    #
    # Returns nothing.
    def output_loop
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
    end
  end
end
