# Define the ArsModels::BaseWithContext class.

module ArsModels
  # TODO: Document ArsModels::BaseWithContext
  class BaseWithContext < Base
    # TODO: Document BaseWithContext#context
    attr_accessor :context

    # TODO: Document BaseWithContext.context_instance
    def self.context_instance(context)
      context = Context.new(context) unless context.is_a?(Context)
      context_class = self.clone
      context_class_metaclass = class << context_class; self; end
      context_class_metaclass.instance_eval do
        define_method(:context) {context}
      end
      context_class
    end

    # TODO: Document BaseWithContext.context
    def self.context
      nil
    end
  end
end