require 'rexml/document'
require 'ars_models'

class KineticHelperRecordRetrieveV2
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
      ['KS_SRV_Helper']
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
    entry = @@remedy_forms['KS_SRV_Helper'].find_entries(
      :single,
      :conditions => [%|'Request ID' = "#{@parameters['Request ID']}"|],
      :fields => :all
    )

    if entry.nil?
      raise(%|An entry can't be found in KS_SRV_Helper for (Request ID)="#{@parameters['Request ID']} "|)
    end

    # Build up a list of all field names and values for this record
    field_values = entry.field_values.collect do |field_id, value|
      "#{@@remedy_forms['KS_SRV_Helper'].field_for(field_id).name}: #{value}"
    end
	puts("Field Values: #{field_values.inspect}") if @debug_logging_enabled

    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
		<result name='Status'>#{escape(entry['Status'].value)}</result>
		<result name='SurveyInstanceID'>#{escape(entry['SurveyInstanceID'])}</result>
		<result name='CustomerSurveyInstanceID'>#{escape(entry['CustomerSurveyInstanceID'])}</result>
		<result name='Character Field1'>#{escape(entry['Character Field1'])}</result>
		<result name='Character Field2'>#{escape(entry['Character Field2'])}</result>
		<result name='Character Field3'>#{escape(entry['Character Field3'])}</result>
		<result name='Character Field4'>#{escape(entry['Character Field4'])}</result>
		<result name='Character Field5'>#{escape(entry['Character Field5'])}</result>
		<result name='Character Field6'>#{escape(entry['Character Field6'])}</result>
		<result name='Character Field7'>#{escape(entry['Character Field7'])}</result>
		<result name='Character Field8'>#{escape(entry['Character Field8'])}</result>
		<result name='Character Field9'>#{escape(entry['Character Field9'])}</result>
		<result name='Character Field10'>#{escape(entry['Character Field10'])}</result>
		<result name='Character Field11'>#{escape(entry['Character Field11'])}</result>
		<result name='Character Field12'>#{escape(entry['Character Field12'])}</result>
		<result name='Character Field13'>#{escape(entry['Character Field13'])}</result>
		<result name='Character Field14'>#{escape(entry['Character Field14'])}</result>
		<result name='Integer Field1'>#{escape(entry['Integer Field1'])}</result>
		<result name='Integer Field2'>#{escape(entry['Integer Field2'])}</result>
		<result name='Integer Field3'>#{escape(entry['Integer Field3'])}</result>
		<result name='Integer Field4'>#{escape(entry['Integer Field4'])}</result>
		<result name='Integer Field5'>#{escape(entry['Integer Field5'])}</result>
		<result name='Integer Field6'>#{escape(entry['Integer Field6'])}</result>
		<result name='Date Field1'>#{escape(entry['Date Field1'])}</result>
		<result name='Date Field2'>#{escape(entry['Date Field2'])}</result>
		<result name='Date Field3'>#{escape(entry['Date Field3'])}</result>
		<result name='Date Field4'>#{escape(entry['Date Field4'])}</result>
		<result name='Date Field5'>#{escape(entry['Date Field5'])}</result>
		<result name='Date Field6'>#{escape(entry['Date Field6'])}</result>
		<result name='Date Field7'>#{escape(entry['Date Field7'])}</result>
		<result name='Date/Time Field1'>#{escape(entry['Date/Time Field1'])}</result>
		<result name='Date/Time Field2'>#{escape(entry['Date/Time Field2'])}</result>
		<result name='Date/Time Field3'>#{escape(entry['Date/Time Field3'])}</result>
		<result name='Date/Time Field4'>#{escape(entry['Date/Time Field4'])}</result>
		<result name='Date/Time Field5'>#{escape(entry['Date/Time Field5'])}</result>
		<result name='Date/Time Field6'>#{escape(entry['Date/Time Field6'])}</result>
		<result name='Date/Time Field7'>#{escape(entry['Date/Time Field7'])}</result>
		<result name='Time Field1'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field2'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field3'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field4'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field5'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field6'>#{escape(entry['Time Field1'])}</result>
		<result name='Time Field7'>#{escape(entry['Time Field1'])}</result>
		<result name='Index Field1'>#{escape(entry['Index Field1'])}</result>
		<result name='Index Field2'>#{escape(entry['Index Field2'])}</result>
		<result name='Index Field3'>#{escape(entry['Index Field3'])}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
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
