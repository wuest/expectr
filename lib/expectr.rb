require 'pty'
require 'timeout'
require 'thread'

require 'expectr/error'

# Public: Expectr is an API to the functionality of Expect (see
# http://expect.nist.gov) implemented in ruby.
#
# Expectr contrasts with Ruby's built-in Expect class by avoiding tying in
# with the IO class, instead creating a new object entirely to allow for more
# grainular control over the execution and display of the program being
# run.
#
# Examples
#
#   # SSH Login to another machine
#   exp = Expectr.new('ssh user@example.com')
#   exp.expect("Password:")
#   exp.send('password')
#   exp.interact!(blocking: true)
#
#   # See if a web server is running on the local host, react accordingly
#   exp = Expectr.new('netstat -ntl|grep ":80 " && echo "WEB"', timeout: 1)
#   if exp.expeect("WEB")
#     # Do stuff if we see 'WEB' in the output
#   else
#     # Do other stuff
#   end
class Expectr
  # Public: Gets/sets the number of seconds a call to Expectr#expect may last
  attr_accessor :timeout
  # Public: Gets/sets the number of bytes to use for the internal buffer
  attr_accessor :buffer_size
  # Public: Gets/sets whether to constrain the buffer to the buffer size
  attr_accessor :constrain
  # Public: Gets/sets whether to flush program output to STDOUT
  attr_accessor :flush_buffer
  # Public: Returns the PID of the running process
  attr_reader :pid
  # Public: Returns the active buffer to match against
  attr_reader :buffer
  # Public: Returns the buffer discarded by the latest call to Expectr#expect
  attr_reader :discard

  # Public: Initialize a new Expectr object.
  # Spawns a sub-process and attaches to STDIN and STDOUT for the new process.
  #
  # cmd  - A String or File referencing the application to launch
  # args - A Hash used to specify options for the new object (default: {}):
  #        :timeout      - Number of seconds that a call to Expectr#expect has
  #                        to complete (default: 30)
  #        :flush_buffer - Whether to flush output of the process to the
  #                        console (default: true)
  #        :buffer_size  - Number of bytes to attempt to read from sub-process
  #                        at a time.  If :constrain is true, this will be the
  #                        maximum size of the internal buffer as well.
  #                        (default: 8192)
  #        :constrain    - Whether to constrain the internal buffer from the
  #                        sub-process to :buffer_size (default: false)
  def initialize(cmd, args={})
    unless cmd.kind_of? String or cmd.kind_of? File
      raise ArgumentError, "String or File expected"
    end

    cmd = cmd.path if cmd.kind_of? File

    @buffer = ''.encode("UTF-8")
    @discard = ''.encode("UTF-8")

    @timeout = args[:timeout] || 30
    @flush_buffer = args[:flush_buffer].nil? ? true : args[:flush_buffer]
    @buffer_size = args[:buffer_size] || 8192
    @constrain = args[:constrain] || false

    @out_mutex = Mutex.new
    @out_update = false
    @interact = false

    @stdout,@stdin,@pid = PTY.spawn(cmd)

    Thread.new do
      while @pid > 0
        unless select([@stdout], nil, nil, @timeout).nil?
          buf = ''.encode("UTF-8")

          begin
            @stdout.sysread(@buffer_size, buf)
          rescue Errno::EIO #Application went away.
            @pid = 0
            break
          end

          force_utf8(buf) unless buf.valid_encoding?
          print_buffer(buf)

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

  # Public: Relinquish control of the running process to the controlling
  # terminal, acting as a pass-through for the life of the process.  SIGINT
  # will be caught and sent to the application as "\C-c".
  #
  # args - A Hash used to specify options to be used for interaction (default:
  #        {}):
  #        :flush_buffer - explicitly set @flush_buffer to the value specified
  #        :blocking     - Whether to block on this call or allow code
  #                        execution to continue (default: false)
  #
  # Returns the interaction Thread
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
      input = ''.encode("UTF-8")
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

  # Public: Report whether or not current Expectr object is in interact mode
  #
  # Returns true or false
  def interact?
    @interact
  end

  # Public: Cause the current Expectr object to drop out of interact mode
  #
  # Returns nothing.
  def leave!
    @interact=false
  end

  # Public: Kill the running process, raise ProcessError if the pid isn't > 1
  #
  # signal - Symbol, String, or Fixnum representing the signal to send to the
  #          running process. (default: :TERM)
  #
  # Returns true if the process was successfully killed, false otherwise
  def kill!(signal=:TERM)
    raise ProcessError unless @pid > 0
    (Process::kill(signal.to_sym, @pid) == 1)
  end

  # Public: Send input to the active process
  #
  # str - String to be sent to the active process
  #
  # Returns nothing.
  # Raises Expectr::ProcessError if the process isn't running
  def send(str)
    begin
      @stdin.syswrite str
    rescue Errno::EIO #Application went away.
      @pid = 0
    end
    raise Expectr::ProcessError unless @pid > 0
  end

  # Public: Wraps Expectr#send, appending a newline to the end of the string
  #
  # str - String to be sent to the active process (default: '')
  #
  # Returns nothing.
  def puts(str = '')
    send str + "\n"
  end

  # Public: Begin a countdown and search for a given String or Regexp in the
  # output buffer.
  #
  # pattern     - String or Regexp representing what we want to find
  # recoverable - Denotes whether failing to match the pattern should cause the
  #               method to raise an exception (default: false)
  #
  # Examples
  #
  #   exp.expect("this should exist")
  #   # => MatchData
  #
  #   exp.expect("this should exist") do
  #     # ...
  #   end
  #
  #   exp.expect(/not there/)
  #   # Raises Timeout::Error
  #
  #   exp.expect(/not there/, true)
  #   # => nil
  # 
  # Returns a MatchData object once a match is found if no block is given
  # Yields the MatchData object representing the match
  # Raises TypeError if something other than a String or Regexp is given
  # Raises Timeout::Error if a match isn't found in time, unless recoverable
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

  # Public: Clear output buffer
  #
  # Returns nothing.
  def clear_buffer!
    @out_mutex.synchronize do
      @buffer = ''.encode("UTF-8")
      @out_update = false
    end
  end

  # Internal: Print buffer to STDOUT if @flush_buffer is true
  #
  # buf - String to be printed to STDOUT
  #
  # Returns nothing.
  def print_buffer(buf)
    print buf if @flush_buffer
    STDOUT.flush unless STDOUT.sync
  end

  # Internal: Encode a String twice to force UTF-8 encoding, dropping           
  # problematic characters in the process.                                      
  #                                                                             
  # buf  - String to be encoded.                                                
  #                                                                             
  # Returns the encoded String.                                                 
  def force_utf8(buf)                                                           
    buf.force_encoding('ISO-8859-1').encode('UTF-8', 'UTF-8', replace: nil)     
  end                                                                           
end
