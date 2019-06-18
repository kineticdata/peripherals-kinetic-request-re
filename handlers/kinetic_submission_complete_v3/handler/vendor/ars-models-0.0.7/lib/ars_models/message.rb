# Define the ArsModels::Message class.

module ArsModels
  # TODO: Document ArsModels::Message
  class Message < Base
    # TODO: Document ArsModels::Message#message accessor
    attr_accessor :message
    # TODO: Document ArsModels::Message#message_number accessor
    attr_accessor :message_number
    # TODO: Document ArsModels::Message#type accessor
    attr_accessor :type

    # TODO: Document ArsModels::Message#initialize
    def initialize(*args)
      super(*args)
    end

  private
    def build(options={})
      [:message, :message_number, :type].each do |attribute|
        self.send("#{attribute}=", options[:attribute]) if options.has_key?(:attribute)
      end
    end

    def generate(ars_message, options={})
      # Validate the passed options
      validate_options(options, :required => [], :optional => [:message, :message_number, :type])

      # Raise an error if the provided object is not actually a JAPI entry
      raise 'Invalid com.kd.ars.models.datasource.ArsMessage.' unless ars_message.is_a?(ArsMessage)
      
      self.message = ars_message.message
      self.message_number = ars_message.number
      self.type = ars_message.type

      [:message, :message_number, :type].each do |attribute|
        self.send("#{attribute}=", options[:attribute]) if options.has_key?(:attribute)
      end
    end
  end
end