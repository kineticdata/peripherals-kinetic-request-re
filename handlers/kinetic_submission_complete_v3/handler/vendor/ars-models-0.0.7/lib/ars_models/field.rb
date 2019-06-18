# Define the ArsModels::Field class.

module ArsModels
  # Ruby wrapper class for the java com.kd.ars.models.structure.ArsField object.
  # Instances of Field represent a single Ars field.
  class Field < Base
    # Internal JAPI representation of the com.kd.ars.models.structure.ArsField object
    attr_reader :ars_field

    # The field datatype (such as 'CHAR', 'DATE', or 'ATTACHMENT').
    attr_accessor :datatype
    # The default value of the field.
    attr_accessor :default_value
    # The field entrymode (such as 'SYSTEM', 'REQUIRED', or 'OPTIONAL')
    attr_accessor :entrymode
    # The field identifier.
    attr_accessor :id
    # The label of the field on the default view.
    attr_accessor :label
    # The field database name.
    attr_accessor :name

    # Creates a new Field object.  This can be used to generate a Field manually
    # or to build a Field from a JAPI ArsField object.  +name+ and +datatype+
    # are required attributes.
    #
    # <b>Manual Generation:</b>
    #
    # Valid Options: +:datatype+, +:default_value+, +:entrymode+, +:id+,
    # +:label+, +:name+
    #   field = Field.new(:name => 'First Name', :datatype => 'CHAR')
    #
    # <b>JAPI Build:</b>
    #   field = Field.new(new com.kd.ars.models.structure.ArsField('First Name', 'CHAR'))
    def initialize(*args)
      # Call the ArsModels::Base initializer and delegate to the build or generate method
      super(*args)
    end

    def id # :nodoc:
      @ars_field.get_id
    end
    def id=(value) # :nodoc:
      value = value.to_i unless value.nil? || value.is_a?(Fixnum)
      @ars_field.set_id(value)
    end

    def datatype # :nodoc:
      @ars_field.get_datatype
    end
    def datatype=(value) # :nodoc:
      @ars_field.set_datatype(value)
    end

    def default_value # :nodoc:
      @ars_field.get_default_value
    end
    def default_value=(value) # :nodoc:
      @ars_field.set_default_value(value)
    end

    def entrymode # :nodoc:
      @ars_field.get_entrymode
    end
    def entrymode=(value) # :nodoc:
      @ars_field.set_entrymode(value)
    end

    def label # :nodoc:
      @ars_field.get_label
    end
    def label=(value) # :nodoc:
      @ars_field.set_label(value)
    end

    def name # :nodoc:
      @ars_field.get_name
    end
    def name=(value) # :nodoc:
      @ars_field.set_name(value)
    end

    # Returns the xml representation of the field.  For example, field 1
    # (Request ID) would be in the following format:
    #   <field datatype="CHAR" entrymode="SYSTEM" id="1" label="Request ID" name="Request ID"/>
    def to_xml
      # Defer xml generation to the com.kd.ars.models.structure.ArsField object
      @ars_field.to_xml_string
    end

  private
    def build(options={})
      # Validate the options
      validate_options(options, :required => [:name], :optional => [:datatype, :id, :label, :entrymode, :default_value, :options])

      # Store a new JAPI ArsField object
      if options[:options]
        ars_enum_options = []
        options[:options].each_with_index do |option, index|
          ars_enum_options << ArsEnumFieldOption.new((option[:id] || index).to_s, option[:name], option[:label] || option[:name])
        end
        @ars_field = ArsEnumField.new(options[:name], ars_enum_options.to_java(:'com.kd.ars.models.structure.ArsEnumFieldOption'))
      else
        @ars_field = ArsField.new(options[:name], options[:datatype])
      end

      [:id, :label, :entrymode, :default_value].each do |key|
        self.send("#{key}=", options[key]) if options.has_key?(key)
      end
    end

    def generate(japi_object, options={})
      # Raise an error if the provided object is not actually a JAPI field
      raise 'Invalid com.kd.ars.models.structure.ArsField.' unless japi_object.is_a?(ArsField)

      # Store the JAPI ArsField object
      @ars_field = japi_object
      # If there were options passed in with the ArsField object, overwrite the object with those values
      options.keys.each do |key|
        if [:id, :name, :label, :datatype, :entrymode, :default_value].include?(key)
          self.send("#{key}=", options[key]) if options.has_key?(key)
        end
      end
    end
  end
end