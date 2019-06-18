require 'rexml/document'
require 'ars_models'

class KineticRequestApprovalCreateV4
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
        'KS_SRV_SurveyTemplate'
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

    # Store the fields to retrieve from the originating record but that are not
    # cloned to the approval record.  These can't be cloned since they are
    # unique identifiers for each record, but are required to be retrieved so
    # that the approval 'Originating Id', 'Lookup Id', and 'Originating Id
    # Display' values can be properly mapped.
    @additional_fields = ['instanceId', 'OriginatingID', 'OriginatingID_Display']

    # Ensure that fields required for retrieving additional data are included in
    # the submission retrieval.
    ['ApplicationName', 'Category'].each do |field|
      (@additional_fields << field) unless @fields_to_clone.include?(field)
    end
  end

  # Creates a KS_SRV_CustomerSuvey_base record with the 'Submit Type' of
  # "Approval."  The purpose of this record is to invoke the Kinetic Request
  # approval processing (see the README for more information).  The approval
  # record is related to the original submission via the value of the
  # 'Originating Id' field.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Retrieve the initial field values from the triggering base record.  These
    # will be copied into the approval record so that the data submitted by the
    # original submission can be used within the approval.
    submission = retrieve_submission(@parameters['lookup_id'],
      @fields_to_clone + @additional_fields)

    # Initialize the Hash of field values based on the retrieved request record.
    # This builds a Hash that maps the KS_SRV_CustomerSurey_base database field
    # name to its values (and skips fields that should not be mapped, such as
    # 'Request Id' and 'instanceId').
    submission_values = submission.field_values.inject({}) do |hash, (field_id, field_value)|
      # Determine the database name of the associated field
      field_name = @@remedy_forms['KS_SRV_CustomerSurvey_base'].field_for(field_id).name
      # Add the field name to value map unless the field was specified in the
      # @additional_fields attribute (this prevents the duplicating of instance
      # id and request id).
      @additional_fields.include?(field_name) ? hash : hash.merge!(field_name => field_value)
    end

    # Retrieve the originating submission so that we can manually populate the
    # originating id values.  This is necessary since Kinetic Request does not
    # set the OriginatingID or OriginatingID_Display on the originating record
    # itself, so these are not populated in the submission to be approved.
    originating_submission = retrieve_submission(submission['OriginatingID'], 
      ['instanceId', 'CustomerSurveyID', 'Survey_Template_Name'])

    # Merge the originating request values with the field values specified as
    # parameters (such as the Message Template and Approval Template).  This
    # gives precedence to the field values specified by the node.xml mapping.
    @field_values = submission_values.merge(@field_values)

    # Merge in the specified lookup Ids.  These are used to relate the approval
    # record to the originating record.
    # * Form (labeled as Originating Form) - This field is used to hold the name
    #   of the originating service item.
    # * LookupValueId - The instance id of the Kinetic Request submission that
    #   the approval is being created for.  This is different from the
    #   OriginatingID only when doing nested approvals.
    # * OriginatingID - The instance id of the original Kinetic Request
    #   submission.
    # * OriginatingID_Display - The request id of the original Kinetic Request
    #   submission.
    @field_values.merge!(
      'LookupValueId' => submission['instanceId'],
      'Form' => originating_submission['Survey_Template_Name'],
      'OriginatingID' => originating_submission['instanceId'],
      'OriginatingID_Display' => originating_submission['CustomerSurveyID']
    )

    # Use the Approval Template Name and Approval Template Catalog Name
    # parameters to retrieve and add the SurveyInstanceID to the @field_values
    # hash.
    @field_values['SurveyInstanceID'] = get_survey_template_id(
      @parameters['approval_template_name'], @parameters['approval_template_catalog_name'])
    # Use the Message Template Name parameter to retrieve and add the
    # MessageTemplateInstanceID to the @field_values hash.
    if (@parameters['message_template_name'])
      @field_values['MessageTemplateInstanceID'] = get_message_template_id(
        @parameters['message_template_name'], @field_values['ApplicationName'])
    end

    # Log the field value map (if debug logging is enabled)
    puts(format_hash("Approval Record Field Values:", @field_values)) if @debug_logging_enabled
    
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
  def get_message_template_id(message_template_name, application_name)
    entry = @@remedy_forms['KS_MSG_MessageTemplate'].find_entries(
      :single,
      :fields     => ['instanceId'],
      :conditions => [%`'Message_Template_Name'="#{message_template_name}" AND 'ApplicationName'="#{application_name}"`]
    )
    if entry.nil?
      raise %|Unable to find message template "#{message_template_name}" in application "#{application_name}"|
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

  # Retrieve the ArsModels::Entry object for the KS_SRV_CustomerSuvey_base
  # record associated to the specified instance id and include the specified
  # fields.
  #
  # Raises an exception if a record associated to the specified instance id does
  # not exist.
  #
  # ==== Parameters
  # * id (String) - The instance Id of the KS_SRV_CustomerSurvey_base record
  #   that should be retrieved.
  # * field_identifiers (Array) - An array of field identifiers, typically field
  #   ids (specified as numbers) or field names (specified as strings), that
  #   should be returned with the requested submission.
  #
  # ==== Returns
  # An ArsModels::Entry record that includes the field values of the located
  # KS_SRV_CustomerSurvey_base record.
  def retrieve_submission(id, field_identifiers=nil)
    entry = @@remedy_forms['KS_SRV_CustomerSurvey_base'].find_entries(
      :single, :fields => field_identifiers, :conditions => [%`'179' = "#{id}"`]
    )
    raise %|Unable to find the initial request record '#{id}'.| if entry.nil?
    entry
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