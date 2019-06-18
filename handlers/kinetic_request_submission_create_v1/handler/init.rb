require 'rexml/document'
require 'ars_models'

class KineticRequestSubmissionCreateV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_SRV_CustomerSurvey_base database field names
  #   to the values to be used for the approval record.
  # * @fields_to_clone - An array of KS_SRV_CustomerSurvey_base database field
  #   names that should be copied from the originating record to the approval
  #   record.
  # * @additional_fields - An Array of KS_SRV_CustomerSurvey_base database field
  #   names that need to be retrieved with the originating record but that are
  #   not set on the approval record.
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
      [
        'KS_SRV_CustomerSurvey_base',
        'KS_MSG_MessageTemplate',
        'KS_SRV_SurveyTemplate',
        'KS_SRV_SurveyQuestion'
      ]
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Retrieve the list of field values that will be written to the approval record
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts(format_hash("Initial Field Values:", @field_values)) if @debug_logging_enabled

    # Store a list of fields that should be cloned
    @fields_to_clone = []
    REXML::XPath.match(@input_document, '/handler/clonedFields/field').each do |node|
      @fields_to_clone << node.attribute('name').value
    end

  end

  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
	@field_values['Category'] = @parameters['template_catalog_name']
	# Use the Template Name and Template Catalog Name
    # parameters to retrieve and add the SurveyInstanceID to the @field_values
    # hash.
	@field_values['SurveyInstanceID'] = get_survey_template_id(@parameters['template_name'], @parameters['template_catalog_name'])
    # Use the Message Template Name parameter to retrieve and add the
    # MessageTemplateInstanceID to the @field_values hash.
    
	if !@parameters['message_template_name'].nil? && @parameters['message_template_name']!=""
		@field_values['MessageTemplateInstanceID'] = get_message_template_id(@parameters['message_template_name'])
	end
	
    # Create the KS_SRV_CustomerSurvey_base record using the @field_values hash
    # that was built up.  Pass 'instanceId' is passed to the fields argument to
    # explicitely specify the field values to return (this improves performance
    # over retrieving all fields on the submission record).
    entry = @@remedy_forms['KS_SRV_CustomerSurvey_base'].create_entry!(
      :field_values => @field_values,
      :fields       => ['instanceId']
    )
    
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Instance Id">#{escape(entry['instanceId'])}</result>
	  <result name="KSR">#{escape(entry.id)}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
  end

  ##############################################################################
  # Kinetic Approval handler utility functions
  ##############################################################################

  # Retrieves the Id of the KS_MSG_MessageTemplate record that is associated to
  # the specified message template and application name.
  #
  # Raises an exception if there were no KS_MSG_MessageTemplate records that
  # match the specified message template and application name.
  #
  # ==== Parameters
  # * message_template_name (String) - The name of the desired message template.
  # * application_name (String) - The name of the application that the desired
  #   message template is associated to.
  #
  # ==== Returns
  # A String representing the Instance Id of the located KS_MSG_MessageTemplate
  # record.
  def get_message_template_id(message_template_name)
    entry = @@remedy_forms['KS_MSG_MessageTemplate'].find_entries(
      :single,
      :fields     => ['instanceId'],
      :conditions => [%`'Message_Template_Name'="#{message_template_name}" AND 'ApplicationName'="Kinetic Request"`]
    )
    if entry.nil?
      raise %|Unable to find message template "#{message_template_name}" in application Kinetic Request|
    end
    entry['instanceId']
  end

  # Retrieves the Id of the KS_SRV_SuveyTemplate record that is associated to
  # the specified survey template and catalog names.
  #
  # Raises an exception if there were no KS_SRV_SurveyTemplate records that
  # match the specified template and catalog name.
  # 
  # ==== Parameters
  # * survey_template_name (String) - The name of the desired survey template.
  # * catalog_name (String) - The name of the catalog that the desired survey
  #   template is associated to.
  #
  # ==== Returns
  # A String representing the Instance Id of the located KS_SRV_SuveyTemplate
  # record.
  def get_survey_template_id(survey_template_name, catalog_name)
    entry = @@remedy_forms['KS_SRV_SurveyTemplate'].find_entries(
      :single,
      :fields     => ['instanceId'],
      :conditions => [%`'Category'="#{catalog_name}" AND 'Survey_Template_Name'="#{survey_template_name}"`]
    )
    if entry.nil?
      raise %|Unable to find template "#{survey_template_name}" in catalog "#{catalog_name}"|
    end
    entry['instanceId']
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
    # Starting with the "header" parameter string, concatenate each of the
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
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end