class Expectr
  module Interface
    def init_instance
      methods = []
      public_methods.select { |m| m =~ /^interface_/ }.each do |name|
        method = public_method(name)
        name = name.to_s.gsub(/^interface_/, '').to_sym
        methods << [name, method]
      end
      methods
    end

    def interact_thread
      Thread.new { }
    end
  end
end
