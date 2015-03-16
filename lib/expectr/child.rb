require 'pty'
require 'expectr'
require 'expectr/interface'

class Expectr
  # Public: The Expectr::Child Module defines the interface for interacting
  # with child processes.
  module Child
    include Expectr::Interface

    # Public: Initialize the Expectr interface, spawning a sub-process
    # attaching to STDIN and STDOUT of the new process.
    #
    # args - A Hash containing arguments to Expectr.  Only :cmd is presently
    #        used for this function.
    #        :cmd - A String or File referencing the application to launch.
    #
    # Returns nothing.
    # Raises TypeError if args[:cmd] is anything other than String or File.
    def init_interface(args)
      cmd = args[:cmd]
      cmd = cmd.path if cmd.kind_of?(File)

      unless cmd.kind_of?(String)
        raise(TypeError, Errstr::STRING_FILE_EXPECTED)
      end

      @stdout,@stdin,@pid = PTY.spawn(cmd)
      @stdout.winsize = $stdout.winsize if $stdout.tty?
    end

    # Public: Send a signal to the running child process.
    #
    # signal - Symbol, String or FixNum indicating the symbol to be sent to the
    #          running process. (default: :TERM)
    #
    # Returns a boolean indicating whether the process was successfully sent
    # the signal.
    # Raises ProcessError if the process is not running (@pid = 0).
    def kill!(signal = :TERM)
      unless @pid > 0
        raise(ProcessError, Errstr::PROCESS_NOT_RUNNING)
      end
      Process::kill(signal.to_sym, @pid) == 1
    end

    # Public: Send input to the active child process.
    #
    # str - String to be sent.
    #
    # Returns nothing.
    # Raises Expectr::ProcessError if the process is not running (@pid = 0).
    def send(str)
      begin
        @stdin.syswrite str
      rescue Errno::EIO, EOFError # Application is not running
        @pid = 0
      end
      unless @pid > 0
        raise(Expectr::ProcessError, Errstr::PROCESS_GONE)
      end
    end

    # Public: Read the output of the child process, force UTF-8 encoding, then
    # append to the internal buffer and print to $stdout if appropriate.
    #
    # Returns nothing.
    def output_loop
      while @pid > 0
        unless select([@stdout], nil, nil, @timeout).nil?
          buf = ''

          begin
            @stdout.sysread(@buffer_size, buf)
          rescue Errno::EIO, EOFError #Application is not running
            @pid = 0
            @thread.wakeup if @thread
            return
          end
          process_output(buf)
        end
      end
    end

    # Public: Return the PTY's window size.
    #
    # Returns a two-element Array (same as IO#winsize)
    def winsize
      @stdout.winsize
    end

    private

    # Internal: Set up the execution environment to prepare for entering
    # interact mode.
    # Presently assumes a Linux system.
    #
    # Returns nothing.
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

      # SIGWINCH should trigger an update to the child processes window size
      env[:sig]['WINCH'] = trap 'WINCH' do
        @stdout.winsize = $stdout.winsize
      end

      env
    end

    # Internal: Create a Thread containing the loop which is responsible for
    # handling input from the user while in interact mode.
    #
    # Returns a Thread containing the running loop.
    def interact_thread
      @interact = true
      env = prepare_interact_environment
      Thread.new do
        begin
          input = ''

          while @pid > 0 && @interact
            if select([$stdin], nil, nil, 1)
              c = $stdin.getc.chr
              send c unless c.nil?
            end
          end
        ensure
          restore_environment(env)
        end
      end
    end
  end
end
