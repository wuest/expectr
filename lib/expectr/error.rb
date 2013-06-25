class Expectr
  # Public: Denotes a problem with the running Process associated with a
  # Child Interface
  class ProcessError < StandardError; end

  module Interface
    # Public: Denotes an interface which cannot be killed (e.g. Lambda Interface)
    class NotKillableError < StandardError; end
  end

  class Interpreter
    # Public: Denotes that input was attempted to be sent to a non-existant
    # process.
    class NotRunningError < StandardError; end
  end
end
