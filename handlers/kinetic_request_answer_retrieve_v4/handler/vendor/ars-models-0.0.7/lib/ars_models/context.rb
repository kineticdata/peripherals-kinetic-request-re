# Define the ArsModels::Context class.

module ArsModels
  # Ruby wrapper class for the java com.kd.ars.models.datasource.ArsContext
  # object.  Instances of Context represent a single AR server user.
  class Context < Base
    # Store the internal java representation of the context
    attr_reader :ars_context

    # Password for the AR server user context.
    attr_accessor :password
    # Ar Server connection port associated with the AR server user context.
    attr_accessor :port
    # Server ip or dns name associated with the AR server user context.
    attr_accessor :server
    # Username for the AR server user context.
    attr_accessor :username
    # RPC program number of the server. Specify 390600 to use the admin queue, a
    # number from 390621 to 390634 or 390636 to 390669 or 390680-390694 to use a
    # private queue, or 0 (default) to use the fast or list server queue.
    # This parameter is overridden by the ARRPC environment variable.
    attr_accessor :prognum
    # Authentication string for the AR server user context.
    attr_accessor :authentication

    # Creates a new Context object.  This can be used to generate a Context
    # manually or to build a Context from a JAPI ArsContext object.  +server+
    # and +username+ are required attributes.
    #
    # <b>Manual Generation:</b>
    #
    # Valid Options: +:username+, +:password+, +:server+, +:port+, +:authentication+, +:prognum+
    #   context = Context.new(:username => 'Demo', :password => '', :server => '127.0.0.1', :authentication => 'MyDomain', :port => 5000, :prognum => 390636 )
    #
    # <b>JAPI Build:</b>
    #   field = Context.new(new com.kd.ars.models.structure.ArsContext('Demo', '', '127.0.0.1', 'MyDomain', 5000, 390636))
    def initialize(*args)
      # Call the ArsModels::Base initializer and delegate to the build or generate method
      super(*args)
    end

    def username # :nodoc:
      @ars_context.get_username
    end
    def username=(value) # :nodoc:
      @ars_context.set_username(value)
    end
    def password # :nodoc:
      @ars_context.get_password
    end
    def password=(value) # :nodoc:
      @ars_context.set_password(value)
    end
    def server # :nodoc:
      @ars_context.get_server
    end
    def server=(value) # :nodoc:
      @ars_context.set_server(value)
    end
    def authentication # :nodoc:
      @ars_context.get_authentication
    end
    def authentication=(value) # :nodoc:
      @ars_context.set_authentication(value)
    end
    def port # :nodoc:
      @ars_context.get_port
    end
    def port=(value) # :nodoc:
      value = value.to_s.to_i unless value.is_a?(Fixnum) || value.nil?
      begin
        @ars_context.set_port(value)
      rescue NativeException => exception
        raise Exceptions::ModelException.new(exception.cause)
      end
    end
    def prognum # :nodoc:
      @ars_context.get_prognum
    end
    def prognum=(value) # :nodoc:
      value = value.to_s.to_i unless value.is_a?(Fixnum) || value.nil?
      begin
        @ars_context.set_port(value)
      rescue NativeException => exception
        raise Exceptions::ModelException.new(exception.cause)
      end
    end

    # Attempt to log in the AR server user context represented by the Context
    # object.  This method returns an array of hashes representing any AR server
    # messages triggered during log in.  These method hashes include values for
    # the following keys: +:message+, +:type+, +:number+.  If any problems were
    # encountered during login a new ModelException is thrown.
    def login
      begin
        # Try to log in
        @ars_context.login
        # If the login was successful, capture any AR messages
        @ars_context.get_messages.collect do |message|
          {:message => message.get_message, :type => message.get_type, :number => message.get_number}
        end
      rescue NativeException => exception
        # If an exception is thrown, raise a ModelException
        raise Exceptions::ModelException.new(exception.cause)
      end
    end
    
  private
    # TODO: Document ArsModels::Context.build
    def build(options={})
      # Validate the options that were passed in
      validate_options(options, :required => [:server, :username], :optional => [:password, :port, :timezone, :authentication, :prognum])

      # Default the password, authentication, tcp port, and rpc prognum
      options[:password] ||= ""
      options[:authentication] ||= ""
      options[:port] ||= 0
      options[:prognum] ||= 0

      # Attempt to create a new JAPI ArsContext object
      begin
        @ars_context = ArsContext.new(
          options[:username],
          options[:password],
          options[:server],
          options[:authentication],
          options[:port].to_i,
          options[:prognum].to_i
        )
      # If an ARException is thrown (likely due to the inability to set the port)
      rescue NativeException => exception
        raise Exceptions::ModelException.new(exception.cause)
      end
    end

    # TODO: Document ArsModels::Context.generate
    def generate(ars_context, options={})
      # Raise an error if the provided object is not actually a JAPI context
      raise 'Invalid com.kd.ars.models.structure.ArsEntry.' unless ars_context.is_a?(ArsContext)

      # Store the JAPI ArsContext object
      @ars_context = ars_context

      # If there were options passed in with the ArsField object, overwrite the object with those values
      [:username, :password, :server, :authentication, :port, :prognum].each do |attribute|
        self.send("#{attribute}=", options[attribute]) if options.has_key?(attribute)
      end
    end
  end
end
