# Define the ArsModels::Form class.

module ArsModels
  # Ruby wrapper class for the java com.kd.ars.models.structure.ArsForm object
  # Instances of Form represent a single AR server schema / form.
  class Form < BaseWithContext
    # Internal JAPI representation of the com.kd.ars.models.structure.ArsForm object
    attr_reader :ars_form

    # Array of ArsModels::Field objects that represent the fields of the form.
    attr_accessor :fields
    # Array of indexes, which are represented as arrays of ArsModels::Field
    # objects included in the composite index.
    attr_accessor :indexes
    # Hash of AR server group names to the permission type ("HIDDEN" or
    # "VISIBLE") granted to that group.
    attr_accessor :permissions
    # The name of the Form
    attr_accessor :name
    # Array of fields that comprise the default sorting of the form
    attr_accessor :sort_fields

    # TODO: Document ArsModels::Form.initialize
    def initialize(*args)
      # Call the ArsModels::Base initializer and delegate to the build or generate method
      super(*args)
    end

    # TODO: Document ArsModels::Form.create
    def self.create(options={})
      # Default the context if there is a class instance context set via context_instance
      options[:context] ||= context if context
      # Validate the options
      validate_options(
        options,
        :required => [:name, :context],
        :optional => [:fields, :indexes, :permissions, :sort_fields]
      )
      # Save the record
      save(options)
    end

    # TODO: Document ArsModels::Form.delete!
    def self.delete(*args)
      # Pop the last argument if it is an options hash
      options = args.last.is_a?(::Hash) ? args.pop : {}
      options[:context] ||= context if context

      # Validate Options
      validate_options(options, :required => [:context])

      case args[0]
        when nil then return
        when :all then
          # TODO: Feature Completion - Implement delete all
          raise 'Not Implemented'
        else
          forms = args.flatten

          if forms.length == 1
            form_name = forms[0].is_a?(::String) ? forms[0] : forms[0].name
            begin
              new(ArsForm.delete(options[:context].ars_context, form_name, true))
            rescue StandardError => error
              raise Exceptions::InternalError.process(error)
            end
          else
            results, successes, failures = [], {}, {}
            forms.each do |form|
              form_name = form.is_a?(::String) ? form : form.name
              begin
                form = new(ArsForm.delete(options[:context].ars_context, form_name, true), :context => options[:context])
                successes[results.length] = form
                results << form
              rescue StandardError => error
                exception = Exceptions::InternalError.process(error)
                failures[results.length] = exception
                results << exception
              end
            end
            results_metaclass = class << results; self; end
            results_metaclass.instance_eval do
              define_method(:successes) {successes}
              define_method(:failures) {failures}
            end
            results
          end
      end
    end

    # TODO: Document ArsModels::Form.find
    def self.find(*args)
      # Pop the last argument if it is an options hash
      options = args.last.is_a?(::Hash) ? args.pop : {}
      options[:context] ||= context if context

      # Validate that the options are valid
      validate_options(options, :required => [:context], :optional=> [:name, :fields])

      options[:fields] = options[:fields].to_java(:long) if options[:fields]

      case args.first
        when :all then
          name = options[:name] || args[1]
          begin
            ArsForm.find_all(options[:context].ars_context, name, options[:fields]).collect do |form|
              new(form, :context => options[:context])
            end
          rescue StandardError => error
            raise Exceptions::InternalError.process(error)
          end
        else
          args = args[0] if args.length == 1 && args[0].is_a?(::Array)
          results = args.collect do |arg|
            name = arg.is_a?(::String) ? arg : arg.name
            begin
              form = ArsForm.find(options[:context].ars_context, name, options[:fields])
              form ? new(form, :context => options[:context]) : nil
            rescue StandardError => error
              raise Exceptions::InternalError.process(error)
            end
          end
          case results.length
            when 0 then nil
            when 1 then results.first
            else results
          end
      end
    end

    # TODO: Document ArsModels::Form.update
    def self.update(options={})
      raise 'Not Implemented'
    end

    # TODO: Document ArsModels::Form#create
    def create
      raise 'Not Implemented'
    end

    # TODO: Document ArsModels::Form#delete
    def delete(options={})
      # Default the context to the context used to find this form
      options[:context] ||= self.context if self.context
      # Validate the options
      validate_options(options, :required => [:context])
      # Delete the form
      self.class.delete(self, options)
    end

    # TODO: Document ArsModels::Form#update
    def update
      raise 'Not Implemented'
    end

    ########################################################################
    # ENTRY DELEGATED METHODS
    ########################################################################

    # TODO: Document ArsModels::Form#create_entry
    def create_entry!(*args)
      delegate_to_entry('create!', args)
    end

    # TODO: Document ArsModels::Form#delete_entries
    def delete_entries!(*args)
      delegate_to_entry('delete!', args)
    end

    # TODO: Document ArsModels::Form#delete_entry!
    def delete_entry!(id, options={})
      delegate_to_entry('delete!', [id, options])
    end

    # TODO: Document ArsModels::Form#find_entries
    def find_entries(*args)
      delegate_to_entry('find', args)
    end

    # TODO: Document ArsModels::Form#find_entry
    def find_entry(id, options={})
      delegate_to_entry('find', [id, options])
    end

    # TODO: Document ArsModels::Form#update_entries!
    def update_entries!(*args)
      delegate_to_entry('update!', args)
    end

    # TODO: Document ArsModels::Form#update_entry!
    def update_entry!(id, options={})
      delegate_to_entry('update!', [id, options])
    end

    ########################################################################
    # OTHER
    ########################################################################

    # TODO: Document ArsModels::Form.save
    def self.save(options={})
      options[:context] ||= context if context
      
      # Validate the options
      validate_options(
        options,
        :required => [:name, :context],
        :optional => [:fields, :indexes, :permissions, :sort_fields]
      )

      # Remove the context from the options hash
      context = options.delete(:context)

      # Attempt to save the form
      begin
        form = new(options)
        result = new(form.ars_form.save(context.ars_context), :context => options[:context])
      rescue StandardError => exception
        raise Exceptions::InternalError.process(exception)
      end

      # Return the result of the save
      return result
    end

    # TODO: Document ArsModels::Form#save
    def save
      raise 'Not Implemented'
    end

    # TODO: Document ArsModels::Form#field_for
    def field_for(field_identifier)
      ars_field = case field_identifier
        when Field then @ars_form.get_field_by_id(field_identifier.id)
        when ::Fixnum then @ars_form.get_field_by_id(field_identifier)
        when ::NilClass then nil
        when ::String then @ars_form.get_field_by_name(field_identifier)
        when ::Symbol then @ars_form.get_field_by_label(field_identifier.to_s)
        else raise 'Unknown field identifier type.'
      end
      Field.new(ars_field) if ars_field
    end
    alias_method :'[]', :field_for

    # TODO: Document ArsModels::Form#field_id_for
    def field_id_for(field_identifier)
      # TODO: Abstraction - Clean this up
      field = field_for(field_identifier)
      field.id if field
    end

    def field_ids
      fields.collect{|field| field.id}
    end

    def fields # :nodoc:
      @ars_form.get_fields.collect {|ars_field| Field.new(ars_field)}
    end
    def fields=(value) # :nodoc:
      @ars_form.set_fields(value.collect {|field| field.ars_field}.to_java(:'com.kd.ars.models.structure.ArsField'))
    end

    def indexes # :nodoc:
      @ars_form.get_indexes_list.collect do |index|
        index.collect do |field_id|
          field_for(field_id)
        end
      end
    end
    def indexes=(value) # :nodoc:
      array_list = java.util.ArrayList.new
      value.each {|index| array_list.add(index.to_java(:Object)) }
      @ars_form.set_indexes(array_list)
    end

    def permissions # :nodoc:
      @ars_form.get_permissions_array.inject({}) do |hash, permission_tuple|
        hash[permission_tuple[0]] = permission_tuple[1]
        hash
      end
    end
    def permissions=(value) # :nodoc:
      permissions_array = value.inject([]) do |result, permission_tuple|
        result << permission_tuple.to_java(:String) && result
      end
      @ars_form.set_permissions(permissions_array.to_java(:String))
    end

    def sort_field_ids # :nodoc:
      @ars_form.get_sort_fields.to_a
    end
    def sort_fields_ids=(value) # :nodoc:
      @ars_form.set_sort_fields(value.to_java(:Object))
    end

    def name # :nodoc:
      @ars_form.get_name
    end
    def name=(value) # :nodoc:
      @ars_form.set_name(value)
    end

    # TODO: Document ArsModels::Form#to_xml
    def to_xml
      @ars_form.to_xml_string
    end

  private
    DEFAULT_FIELDS = {
      1 => {:datatype => "CHAR", :entrymode => "SYSTEM", :id => 1, :label => 'Request ID', :name => 'Request ID'},
      2 => {:datatype => "CHAR", :entrymode => "REQUIRED", :id => 2, :label => 'Submitter', :name => 'Submitter'},
      3 => {:datatype => "CHAR", :entrymode => "SYSTEM", :id => 3, :label => 'Create Date', :name => 'Create Date'},
      4 => {:datatype => "CHAR", :entrymode => "OPTIONAL", :id => 4, :label => 'Assigned To', :name => 'Assigned To'},
      5 => {:datatype => "CHAR", :entrymode => "SYSTEM", :id => 5, :label => 'Last Modified By', :name => 'Last Modified By'},
      6 => {:datatype => "CHAR", :entrymode => "SYSTEM", :id => 6, :label => 'Modified Date', :name => 'Modified Date'},
      7 => {
        :datatype => "CHAR",
        :entrymode => "REQUIRED",
        :id => 7,
        :label => 'Status',
        :name => 'Status',
        :options => [
          {:id => 0, :name => 'New', :label => 'New'},
          {:id => 1, :name => 'Assigned', :label => 'Assigned'},
          {:id => 2, :name => 'Fixed', :label => 'Fixed'},
          {:id => 3, :name => 'Rejected', :label => 'Rejected'},
          {:id => 4, :name => 'Closed', :label => 'Closed'}
        ]
      },
      8 => {:datatype => "CHAR", :entrymode => "REQUIRED", :id => 8, :label => 'Short Description', :name => 'Short Description'}
    }
    DEFAULT_FIELD_NAMES = {
      'Request ID' => 1,
      'Submitter' => 2,
      'Create Date' => 3,
      'Assigned To' => 4,
      'Last Modified By' => 5,
      'Modified Date' => 6,
      'Status' => 7,
      'Short Description' => 8
    }

    def delegate_to_entry(method, args=[])
      options = args.last.is_a?(::Hash) ? args.pop : {}
      replacement_options = {:form => self}
      replacement_options[:context] = context if context
      args << options.merge(replacement_options)
      ArsModels::Entry.send(method,*args)
    end

    def build(options={})
      # Validate the passed options
      validate_options(
        options,
        :required => [:name],
        :optional => [:context, :fields, :indexes, :permissions, :sort_fields]
      )

      # Store a new JAPI ArsForm object
      @ars_form = ArsForm.new(options[:name])

      # Convert any hash defined fields as fields
      (options[:fields] || []).collect! do |field|
        if field.is_a?(::Hash)
          field = DEFAULT_FIELDS[DEFAULT_FIELD_NAMES[field[:name]]].merge(field) if DEFAULT_FIELD_NAMES.has_key?(field[:name])
          field = DEFAULT_FIELDS[field[:id]].merge(field) if DEFAULT_FIELDS.has_key?(field[:id])
          Field.new(field)
        elsif field.is_a?(Field)
          field
        else
          raise ArgumentException.new("Bad field definition: #{field}")
        end
      end

      [:context, :fields, :indexes, :permissions, :sort_fields].each do |key|
        self.send("#{key}=", options[key]) if options.has_key?(key)
      end
    end

    def generate(ars_form, options={})
      # Raise an error if the provided object is not actually a JAPI entry
      raise 'Invalid com.kd.ars.models.structure.ArsForm.' unless ars_form.is_a?(ArsForm)

      # Validate the passed options
      validate_options(options, :optional => [:context, :fields, :indexes, :name, :permissions, :sort_fields])

      # Store the JAPI ArsField object
      @ars_form = ars_form

      # Convert any hash defined fields as fields
      (options[:fields] || []).collect! do |field|
        field.is_a?(Field) ? field : Field.new(field)
      end

      # If there were options passed in with the ArsForm object, overwrite the object with those values
      [:context, :fields, :indexes, :name, :permissions, :sort_fields].each do |key|
        self.send("#{key}=", options[key]) if options.has_key?(key)
      end
    end
  end
end