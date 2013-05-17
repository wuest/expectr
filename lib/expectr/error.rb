class Expectr
  # Public: Denotes a problem with the running Process associated with a
  # Child Interface
  class ProcessError < StandardError; end

  module Interface
    # Public: Denotes an interface which cannot be killed (e.g. Lambda Interface)
    class NotKillableError < StandardError; end
  end
end
