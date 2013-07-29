class Expectr
  module Interface
    # Public: Return a Thread which does nothing, representing an interface
    # with no functional interact environment available.
    #
    # Returns a Thread.
    def interact_thread
      Thread.new { }
    end

    # Public: Return an empty Hash representing a case where no action needed
    # to be taken in order to prepare the environment for interact mode.
    #
    # Returns an empty Hash.
    def prepare_interact_interface
      {}
    end

    private

    # Internal: Restore environment (TTY parameters, signal handlers) after
    # leaving interact mode.
    #
    # Returns nothing.
    def restore_environment(env)
      env[:sig].each do |signal, handler|
        trap signal, handler
      end
      unless env[:tty].nil?
        `stty #{env[:tty]}`
      end
      @interact = false
    end
  end
end
