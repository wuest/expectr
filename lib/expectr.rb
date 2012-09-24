require 'pty'
require 'timeout'
require 'thread'

require 'expectr/error'

#
# Expectr is an API to the functionality of Expect (see
# http://expect.nist.gov) implemented in ruby.
#
# Expectr contrasts with Ruby's built-in Expect class by avoiding tying in
# with the IO class, instead creating a new object entirely to allow for more
# grainular control over the execution and display of the program being
# run.  See README.rdoc for examples.
#
class Expectr
  # Number of seconds seconds a call to +expect+ may last (default 30)
  attr_accessor :timeout
  # Size of buffer in bytes to attempt to read in at once (default 8 KiB)
  attr_accessor :buffer_size
  # Whether or not to constrain the buffer to buffer_size (default false)
  attr_accessor :constrain
  # Whether to flush program output to STDOUT (default true)
  attr_accessor :flush_buffer
  # PID of running process
  attr_reader :pid
  # Active buffer to match against
  attr_reader :buffer
  # Buffer passed since last call to Expectr#expect
  attr_reader :discard

  #
  # Spawn a sub-process and attach to STDIN and STDOUT for new process.
  # Accepts a String or File as the command, and a Hash containing the
  # remainder of the arguments, with the following keys:
  #
  #   :timeout
  #     Amount of time a call to expect has to complete (default 30)
  #   :flush_buffer
  #     Whether to flush output of the process to STDOUT (default true)
  #   :buffer_size
  #     Size of buffer to keep (if :constrain is true) as well as how much to
  #     attempt to read from the sub-process at once (default 8KiB)
  #   :constrain
  #     Whether to constrain the internal buffer from the sub-process to
  #     :buffer_size (default false)
  #
  def initialize(cmd, args={})
    unless cmd.kind_of? String or cmd.kind_of? File
     raise ArgumentError, "String or File expected"
    end

    cmd = cmd.path if cmd.kind_of? File

    @buffer = String.new
    @discard = String.new
    @timeout = args[:timeout] || 30
    @flush_buffer = args[:flush_buffer].nil? ? true : args[:flush_buffer]
    @buffer_size = args[:buffer_size] || 8192
    @constrain = args[:constrain] || false

    @out_mutex = Mutex.new
    @out_update = false
    @interact = false

    [@buffer, @discard].each {|x| x.encode! "UTF-8" }

    @stdout,@stdin,@pid = PTY.spawn cmd

    Thread.new do
      while @pid > 0
        unless select([@stdout], nil, nil, @timeout).nil?
          buf = ''

          begin
            @stdout.sysread(@buffer_size, buf)
          rescue Errno::EIO #Application went away.
            @pid = 0
            break
          end

          print_buffer buf

          @out_mutex.synchronize do
            @buffer << buf
            if @buffer.length > @buffer_size && @constrain
              @buffer = @buffer[-@buffer_size..-1]
            end
            @out_update = true
          end
        end
      end
    end

    Thread.new do
      Process.wait @pid
      @pid = 0
    end
  end

  # 
  # Relinquish control of the running process to the controlling terminal,
  # acting simply as a pass-through for the life of the process.
  #
  # Interrupts should be caught and sent to the application.
  #
  def interact!(args = {})
    raise ProcessError if @interact

    blocking = args[:blocking] || false
    @flush_buffer = args[:flush_buffer].nil? ? true : args[:flush_buffer]
    @interact = true

    # Save our old tty settings and set up our new environment
    old_tty = `stty -g`
    `stty -icanon min 1 time 0 -echo`

    # SIGINT should be set along to the program
    oldtrap = trap 'INT' do
      send "\C-c"
    end
    
    interact = Thread.new do
      input = ''
      while @pid > 0 && @interact
        if select([STDIN], nil, nil, 1)
          c = STDIN.getc.chr
          send c unless c.nil?
        end
      end

      trap 'INT', oldtrap
      `stty #{old_tty}`
      @interact = false
    end

    blocking ? interact.join : interact
  end

  # 
  # Report whether or not current Expectr object is in interact mode
  #
  def interact?
    @interact
  end

  # 
  # Leave interact mode
  #
  def leave!
    @interact=false
  end

  # 
  # Kill the running process
  #
  def kill!(signal=:HUP)
    raise ProcessError unless @pid > 0
    (Process::kill(signal.to_sym, @pid) == 1)
  end

  #
  # Send input to the currently active process
  #
  def send(str)
    begin
      @stdin.syswrite str
    rescue Errno::EIO #Application went away.
      @pid = 0
    end
    raise Expectr::ProcessError unless @pid > 0
  end

  #
  # Send input to the currently active process, append a newline
  #
  def puts(str)
    send str + "\n"
  end

  #
  # Wait until the timeout value has passed to match a given pattern in the
  # output buffer.  If the timeout is reached, raise an error unless
  # recoverable is true.
  #
  def expect(pattern, recoverable = false)
    match = nil

    case pattern
    when String
      pattern = Regexp.new(Regexp.quote(pattern))
    when Regexp
    else
      raise TypeError, "Pattern class should be String or Regexp"
    end

    begin
      Timeout::timeout(@timeout) do
        while match.nil?
          if @out_update
            @out_mutex.synchronize do
              match = pattern.match @buffer
              @out_update = false
            end
          end
          sleep 0.1
        end
      end

      @out_mutex.synchronize do
        @discard = @buffer[0..match.begin(0)-1]
        @buffer = @buffer[match.end(0)..-1]
        @out_update = true
      end
    rescue Timeout::Error => details
      raise details unless recoverable
    end

    block_given? ? yield(match) : match
  end

  # 
  # Clear output buffer
  #
  def clear_buffer!
    @out_mutex.synchronize do
      @buffer = ''
      @out_update = false
    end
  end

  #
  # Print buffer to STDOUT only if we are supposed to
  #
  def print_buffer(buf)
    print buf if @flush_buffer
    STDOUT.flush unless STDOUT.sync
  end
end
