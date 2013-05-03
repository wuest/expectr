require 'pty'
require 'timeout'
require 'thread'
require 'io/console'

require 'expectr/error'
require 'expectr/version'

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
  DEFAULT_TIMEOUT      = 30
  DEFAULT_FLUSH_BUFFER = true
  DEFAULT_BUFFER_SIZE  = 8192
  DEFAULT_CONSTRAIN    = false
  DEFAULT_FORCE_MATCH  = false

  # Public: Gets/sets the number of seconds a call to Expectr#expect may last
  attr_accessor :timeout
  # Public: Gets/sets whether to flush program output to $stdout
  attr_accessor :flush_buffer
  # Public: Gets/sets the number of bytes to use for the internal buffer
  attr_accessor :buffer_size
  # Public: Gets/sets whether to constrain the buffer to the buffer size
  attr_accessor :constrain
  # Public: Whether to always attempt to match once on calls to Expectr#expect.
  attr_accessor :force_match
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
  #        :force_match  - Whether to always attempt to match against the
  #                        internal buffer on a call to Expectr#expect.  This
  #                        is relevant following a failed call to
  #                        Expectr#expect, which will leave the update status
  #                        set to false, preventing further matches until more
  #                        output is generated otherwise. (default: false)
  def initialize(cmd, args={})
    cmd = cmd.path if cmd.kind_of?(File)
    raise ArgumentError, "String or File expected" unless cmd.kind_of?(String)

    parse_options(args)
    @buffer = ''
    @discard = ''
    @out_mutex = Mutex.new
    @out_update = false
    @interact = false

    @stdout,@stdin,@pid = PTY.spawn(cmd)
    @stdout.winsize = $stdout.winsize if $stdout.tty?

    Thread.new do
      process_output
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

    interact = Thread.new do
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
    @out_update ||= @force_match
    pattern = Regexp.new(Regexp.quote(pattern)) if pattern.kind_of?(String)
    unless pattern.kind_of?(Regexp)
      raise TypeError, "Pattern class should be String or Regexp"
    end

    begin
      Timeout::timeout(@timeout) do
        match = check_match(pattern)
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
      @buffer = ''
      @out_update = false
    end
  end

  # Public: Return the child's window size.
  #
  # Returns a two-element array (same as IO#winsize).
  def winsize
    @stdout.winsize
  end

  # Internal: Print buffer to $stdout if @flush_buffer is true
  #
  # buf - String to be printed to $stdout
  #
  # Returns nothing.
  def print_buffer(buf)
    print buf if @flush_buffer
    $stdout.flush unless $stdout.sync
  end

  # Internal: Encode a String twice to force UTF-8 encoding, dropping           
  # problematic characters in the process.                                      
  #                                                                             
  # buf  - String to be encoded.                                                
  #                                                                             
  # Returns the encoded String.                                                 
  def force_utf8(buf)                                                           
    return buf if buf.valid_encoding?
    buf.force_encoding('ISO-8859-1').encode('UTF-8', 'UTF-8', replace: nil)     
  end                                                                           

  private

  # Internal: Determine values of instance options and set instance variables
  # appropriately, allowing for default values where nothing is passed.
  #
  # args - A Hash used to specify options for the new object (default: {}):
  #        :timeout      - Number of seconds that a call to Expectr#expect has
  #                        to complete.
  #        :flush_buffer - Whether to flush output of the process to the
  #                        console.
  #        :buffer_size  - Number of bytes to attempt to read from sub-process
  #                        at a time.  If :constrain is true, this will be the
  #                        maximum size of the internal buffer as well.
  #        :constrain    - Whether to constrain the internal buffer from the
  #                        sub-process to :buffer_size.
  #        :force_match  - Whether to always attempt to match against the
  #                        internal buffer on a call to Expectr#expect.  This
  #                        is relevant following a failed call to
  #                        Expectr#expect, which will leave the update status
  #                        set to false, preventing further matches until more
  #                        output is generated otherwise.
  #
  # Returns nothing.
  def parse_options(args)
    @timeout = args[:timeout] || DEFAULT_TIMEOUT
    @buffer_size = args[:buffer_size] || DEFAULT_BUFFER_SIZE
    @constrain = args[:constrain] || DEFAULT_CONSTRAIN
    @force_match = args[:force_match] || DEFAULT_FORCE_MATCH
    @flush_buffer = args[:flush_buffer]
    @flush_buffer = DEFAULT_FLUSH_BUFFER if @flush_buffer.nil?
  end

  # Internal: Read from the process's stdout.  Force UTF-8 encoding, append to
  # the internal buffer, and print to $stdout if appropriate.
  #                                                                             
  # Returns nothing.
  def process_output
    while @pid > 0
      unless select([@stdout], nil, nil, @timeout).nil?
        buf = ''

        begin
          @stdout.sysread(@buffer_size, buf)
        rescue Errno::EIO #Application went away.
          @pid = 0
          return
        end

        print_buffer(force_utf8(buf))

        @out_mutex.synchronize do
          @buffer << buf
          if @constrain && @buffer.length > @buffer_size
            @buffer = @buffer[-@buffer_size..-1]
          end
          @out_update = true
        end
      end
    end
  end

  # Internal: Prepare environment for interact mode, saving original
  # environment parameters.
  #                                                                             
  # Returns a Hash object with two keys: :tty containing original tty
  # information and :sig containing signal handlers which have been replaced.
  def prepare_interact_environment
    env = {sig: {}}
    # Save our old tty settings and set up our new environment
    env[:tty] = `stty -g`
    `stty -icanon min 1 time 0 -echo`

    # SIGINT should be sent along to the process.
    env[:sig]['INT'] = trap 'INT' do
      send "\C-c"
    end

    # SIGTSTP should be sent along to the process as well.
    env[:sig]['TSTP'] = trap 'TSTP' do
      send "\C-z"
    end

    # SIGWINCH should trigger an update to the child process
    env[:sig]['WINCH'] = trap 'WINCH' do
      @stdout.winsize = $stdout.winsize
    end

    @interact = true
    env
  end

  # Internal: Restore environment post interact mode from saved parameters.
  #                                                                             
  # Returns nothing.
  def restore_environment(env)
    env[:sig].each_key do |sig|
      trap sig, env[:sig][sig]
    end
    `stty #{env[:tty]}`
    @interact = false
  end

  # Internal: Check for a match against a given pattern until a match is found.
  # This method should be wrapped in a Timeout block or otherwise have some
  # mechanism to break out of the loop.
  #
  # Returns a MatchData object containing the match found.
  def check_match(pattern)
    match = nil
    while match.nil?
      if @out_update
        @out_mutex.synchronize do
          match = pattern.match(@buffer)
          @out_update = false
        end
      end
      sleep 0.1
    end
    match
  end
end
