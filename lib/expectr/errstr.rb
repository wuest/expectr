class Expectr
  module Errstr
    EXPECT_WRONG_TYPE = "Pattern should be of class String, Regexp, or Hash"
    ALREADY_INTERACT  = "Already in interact mode"
  end

  module Child
    module Errstr
      STRING_FILE_EXPECTED = "Command should be of type String or File"
      PROCESS_NOT_RUNNING  = "No process is running"
      PROCESS_GONE         = "Child process no longer exists"
    end
  end

  module Adopt
    module Errstr
      IO_EXPECTED = "Arguments of type IO expected"
    end
  end

  class Interpreter
    module Errstr
      BOOLEAN_OR_FIXNUM   = "Boolean or Fixnum expected, received a %s"
      PROCESS_NOT_RUNNING = "No process is running"
    end
  end

  module Lambda
    module Errstr
      PROC_EXPECTED = "Proc Objects expected for reader and writer"
    end
  end
end
