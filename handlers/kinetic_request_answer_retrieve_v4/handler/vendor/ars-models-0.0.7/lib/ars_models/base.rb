# Define the ArsModels::Base class.

module ArsModels
  # TODO: Document ArsModels::Base
  class Base
    # TODO: Document ArsModels::Base#initialize
    def initialize(*args)
      # Pop the last argument if it is an options hash
      options = args.last.is_a?(::Hash) ? args.pop : {}

      # Execute the generation or building of the object based on the arguments provided
      case args.length
        # If there is not a source JAPI object, build from the options
        when 0 then build(options)
        # If there is a source JAPI object, generate from the object
        when 1 then generate(args[0], options)
        # If there was more than one argument, raise an invalid argument error
        else raise "Invalid #{self.class.name} constructor arguments."
      end
    end

    # TODO: Document ArsModels::Base.validate_options
    def self.validate_options(hash, options={})
      # Default the option values
      options[:required] ||= []
      options[:optional] ||= []

      # Get the name of the calling method
      last_call = caller[0]
      calling_method = last_call[last_call.rindex('`')+1..-2].inspect

      # Check for required options
      missing_keys = options[:required] - hash.keys
      raise(ArgumentError, "Missing key(s): #{missing_keys.collect {|key| key.inspect}.join(", ")} for method #{calling_method}") unless missing_keys.empty?

      # Verify there are no unexpected keys
      unknown_keys = hash.keys - [options[:required] + options[:optional]].flatten
      raise(ArgumentError, "Unknown key(s): #{unknown_keys.collect {|key| key.inspect}.join(", ")} for method #{calling_method}") unless unknown_keys.empty?
    end

    # TODO: Document ArsModels::Base#validate_options
    def validate_options(hash, options={})
      # Default the option values
      options[:required] ||= []
      options[:optional] ||= []

      # Get the name of the calling method
      last_call = caller[0]
      calling_method = last_call[last_call.rindex('`')+1..-2].inspect

      # Check for required options
      missing_keys = options[:required] - hash.keys
      raise(ArgumentError, "Missing key(s): #{missing_keys.collect {|key| key.inspect}.join(", ")} for method #{calling_method}") unless missing_keys.empty?

      # Verify there are no unexpected keys
      unknown_keys = hash.keys - [options[:required] + options[:optional]].flatten
      raise(ArgumentError, "Unknown key(s): #{unknown_keys.collect {|key| key.inspect}.join(", ")} for method #{calling_method}") unless unknown_keys.empty?

    end

    # TODO: Document ArsModels::Base#build
    # Build an ArsModels object manually
    def build(*args)
      raise "Method 'build' not implemented for #{self.class.name}"
    end

    # TODO: Document ArsModels::Base#generate
    # Generate an ArsModels object from a source JAPI model
    def generate(*args)
      raise "Method 'generate' not implemented for #{self.class.name}"
    end
  end
end