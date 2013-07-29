require 'expectr'

class Expectr
  # Internal: Provide an interface to Expectr in a manner designed to mimic
  # Expect's original functionality.
  class Interpreter
    DEFAULT_TIMEOUT = 10

    # Public: Filename of currently executing script.
    attr_accessor :filename

    # Public: Initialize a new Expectr Interpreter interface.
    #
    # source - String containing the source to be executed.
    def initialize(source)
      @source = source
      @variables = { timeout: DEFAULT_TIMEOUT }
      @expect = nil
    end

    # Public: Run the source associated with the Interface object.
    #
    # Returns nothing.
    def run
      eval(@source, binding, (@filename || "(expectr)"), 0)
    end

    # Public: Print one or more messages to $stdout.
    #
    # str - String or Array of Strings to print to $stdout.
    #
    # Returns nothing.
    def send_user(*str)
      str.each { |line| $stdout.print line }
    end

    # Public: Set whether output from the active Expectr object should be
    # echoed to the user.
    #
    # enable - Boolean value denoting whether output to the screen should be
    #          enabled.
    #          In order to keep compatibility with Expect, a Fixnum can be
    #          passed, such that any number greater than 0 is evaluated as
    #          true, and 0 or less is false.
    # 
    # Returns nothing.
    # Raises TypeError if enable is not a boolean.
    def log_user(enable)
      if enable.is_a?(Numeric)
        enable = (enable > 0)
      end
      unless enable.is_a?(TrueClass) || enable.is_a?(FalseClass)
        raise(TypeError, Errstr::BOOLEAN_OR_FIXNUM % enable.class.name)
      end

      set(:flush_buffer, enable)
    end

    # Public: Spawn an instance of a command via Expectr.
    #
    # cmd - String referencing the application to spawn.
    #
    # Returns nothing.
    def spawn(cmd)
      @expect = Expectr.new(cmd, @variables)
    end

    # Public: Provide an interface to Expectr#expect.
    #
    # args - Arguments to be passed through to the Expectr object.
    #
    # Returns per Expectr#expect.
    def expect(*args)
      @expect.expect(*args)
    end

    # Public: Send a String to the process referenced by the active Expectr
    # object.
    #
    # str - String to send to the process.
    #
    # Returns nothing.
    # Raises NotRunningError if no Expectr object is active.
    def send(str)
      if @expect.nil?
        raise(NotRunningError, Errstr::PROCESS_NOT_RUNNING)
      end
      @expect.send(str)
    end

    # Public: Terminate any process associated with the Interpreter.
    #
    # Returns nothing.
    def close
      @expect.kill!(:KILL) if @expect.respond_to?(:kill!)
    rescue Expectr::ProcessError
    ensure
      @expect = nil
    end

    private

    # Internal: Set value in internal Hash and update attr_accessor value in
    # the active Expectr object if applicable.
    #
    # variable_name - Name of key to set in the internal Hash.
    # value         - Value to associate with the key.
    #
    # Returns nothing.
    def set(variable_name, value)
      @variables[variable_name] = value
      method_name = (variable_name.to_s + "=").to_sym
      if @expect.methods.include?(method_name)
        @expect.method(method_name).call(value)
      end
    end
  end
end
