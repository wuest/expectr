class Expectr
  module Interface
    # Public: Enumerate and expose all interface functions for a given
    # Interface.
    #
    # Returns a two-dimensional Array containing a name for the new method and
    # a reference to the extant method.
    def init_instance
      methods = []
      public_methods.select { |m| m =~ /^interface_/ }.each do |name|
        method = public_method(name)
        name = name.to_s.gsub(/^interface_/, '').to_sym
        methods << [name, method]
      end
      methods
    end

    # Public: Return a Thread which does nothing, representing an interface
    # with no functional interact environment available.
    #
    # Returns a Thread.
    def interface_interact_thread
      -> {
        Thread.new { }
      }
    end

    # Public: Return an empty Hash representing a case where no action needed
    # to be taken in order to prepare the environment for interact mode.
    #
    # Returns an empty Hash.
    def interface_prepare_interact_interface
      -> {
        {}
      }
    end

    # Internal: Restore environment after interact mode has been left.
    #
    # Returns nothing.
    def interface_restore_environment
      ->(env) {
        env[:sig].each do |signal, handler|
          trap signal, handler
        end
        unless env[:tty].nil?
          `stty #{env[:tty]}`
        end
        @interact = false
      }
    end
  end
end
