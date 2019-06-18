require 'rexml/document'
require 'ars_models'

class KineticRequestSubmissionDatasetRetrieveV2

  Records ||= KineticTask::Consumers::KineticRequest::Records

  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_SRV_CustomerSurvey_base database field names
  #   to the values that will be set on the submission record.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml 
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)
    
    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_CustomerSurvey']
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled
	
	@taskVersion = get_info_value(@input_document, 'taskVersion')

  	# Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

  end
  # Creates a record in the KS_SRV_Helper form
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
  
    # Retrieve a single entry from KS_SRV_Helper form
    base_record = @@remedy_forms['KS_SRV_CustomerSurvey'].find_entries(
      :single,
      :conditions => [%|'CustomerSurveyInstanceId' = "#{@parameters['Submission ID']}" OR 'CustomerSurveyID' = "#{@parameters['Submission ID']}"|],
      :fields => :all
    )
    
    raise "Unable to find KS_SRV_CustomerSurvey record with CustomerSurvey ID or instanceId of: #{@parameters['Submission ID']}" if base_record.nil?
    
	if (@taskVersion == "3")
	#v3
    # Build the template record from the KS_SRV_CustomerSurvey record, which
    # includes the Template fields.
	 template_record = Records::Template.new(base_record)
    
    # Build the template dataset mappings based on the KS_SRV_DataSet form
    # records for dataset specified on the current KS_SRV_CustomerSurvey
    # record.

	 @dataset_hash = Records::TemplateDataSetMapping.find_all(
		  :data_set => template_record.data_set
		).inject({}) do |hash, mapping_record|
		  # Define the current KS_SRV_DataSet record's field_id as a Fixnum
		  field_id = mapping_record.field_id.to_i
		  # Retrieve the ArsModels::Field associated with the current
		  # KS_SRV_CustomerSurvey field.
		  mapping_field = Records::RequestBase.form.field_for(field_id)
		  # Unless the field does not exist on the form, or the field is display only
		  unless mapping_field.nil? || mapping_field.entrymode == "DISPLAY_ONLY"
			# Retrieve the value of the field on the KS_SRV_CustomerSurvey entry
			value = base_record[field_id]
			# Map the KS_SRV_DataSet record's field label value to the field value
			hash[mapping_record.field_label] = value.respond_to?(:value) ? value.value : value
		  end
		  # Return the hash to continue injecting
		  hash
		end
		 puts(format_hash("Dataset Found: ", @dataset_hash)) if @debug_logging_enabled
	
	elsif (@taskVersion == "4")
	  
	  template_record = Records::Template.new(base_record, :context => @@remedy_context)
	  
	  @dataset_hash =  Records::TemplateDataSetMapping.find_all(
		  :data_set => template_record.data_set, :context => @@remedy_context
		).inject({}) do |hash, mapping_record|
		  # Define the current KS_SRV_DataSet record's field_id as a Fixnum
		  field_id = mapping_record.field_id.to_i
		  # Retrieve the ArsModels::Field associated with the current
		  # KS_SRV_CustomerSurvey field.
		  mapping_field = Records::RequestBase.form.field_for(field_id)
		  # Unless the field does not exist on the form, or the field is display only
		  unless mapping_field.nil? || mapping_field.entrymode == "DISPLAY_ONLY"
			# Retrieve the value of the field on the KS_SRV_CustomerSurvey entry
			value = base_record[field_id]
			# Map the KS_SRV_DataSet record's field label value to the field value
			hash[mapping_record.field_label] = value.respond_to?(:value) ? value.value : value
		  end
		  # Return the hash to continue injecting
		  hash
		end
		puts(format_hash("Dataset Found: ", @dataset_hash)) if @debug_logging_enabled
		
	end
    
    dataset_results = ""    
    @dataset_hash.each_pair {|key, value|
      dataset_results << %|<result name="#{key}">#{escape(value)}</result>|
    }
    
    <<-RESULTS
    <results>
     #{dataset_results}
    </results>
    RESULTS
  
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized = true
    end
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided hash
  # name/value pairs.  The String format looks like:
  #   HEADER
  #       KEY1: VAL1
  #       KEY2: VAL2
  # For example, given:
  #   field_values = {'Field 1' => "Value 1", 'Field 2' => "Value 2"}
  #   format_hash("Field Values:", field_values)
  # would produce:
  #   Field Values:
  #       Field 1: Value 1
  #       Field 2: Value 2
  def format_hash(header, hash)
    # Staring with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
