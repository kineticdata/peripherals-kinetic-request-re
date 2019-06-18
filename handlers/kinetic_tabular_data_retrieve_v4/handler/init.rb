# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

class KineticTabularDataRetrieveV4
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
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
    preinitialize_on_first_load(@input_document, ['CUSTOM:KS_SRV_TableData_base'])
	
    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled	
  end
  
  # Uses the Instance ID to retrieve a single entry from the KS:FRB_TableData_base 
  # form.  The purpose of this is to return data elements associated
  # to the entry found.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Retrieve a single entry from KS:FRB_TableData_base based on Remedy Login ID
    entry = @@remedy_forms['CUSTOM:KS_SRV_TableData_base'].find_entries(
      :single,
      :conditions => [%|'179' = "#{@parameters['instance_id']}"|],
      :fields => :all
    )
	
	# Raise error if unable to locate the entry
	raise("No matching entry on the CUSTOM:KS_SRV_TableData_base form for the given instance id [#{@parameters['instance_id']}]") if entry.nil?
	
    # Build up a list of all field names and values for this record
    field_values = entry.field_values.collect do |field_id, value|
      "#{@@remedy_forms['CUSTOM:KS_SRV_TableData_base'].field_for(field_id).name}: #{value}"
    end
	puts("Field Values: #{field_values.inspect}") if @debug_logging_enabled	
	
    # Build the results to be returned by this handler
    results = <<-RESULTS
    <results>
      <result name="CustomerSurveyInstanceID">#{escape(entry['CustomerSurveyInstanceID'])}</result>
      <result name="Survey_Template_Name">#{escape(entry['Survey_Template_Name'])}</result>
      <result name="Table Name">#{escape(entry['Table Name'])}</result>
      <result name="Label1">#{escape(entry['Label1'])}</result>
      <result name="Value1">#{escape(entry['Value1'])}</result>
      <result name="Label2">#{escape(entry['Label2'])}</result>
      <result name="Value2">#{escape(entry['Value2'])}</result>
      <result name="Label3">#{escape(entry['Label3'])}</result>
      <result name="Value3">#{escape(entry['Value3'])}</result>
      <result name="Label4">#{escape(entry['Label4'])}</result>
      <result name="Value4">#{escape(entry['Value4'])}</result>
      <result name="Label5">#{escape(entry['Label5'])}</result>
      <result name="Value5">#{escape(entry['Value5'])}</result>
      <result name="Label6">#{escape(entry['Label6'])}</result>
      <result name="Value6">#{escape(entry['Value6'])}</result>
      <result name="Label7">#{escape(entry['Label7'])}</result>
      <result name="Value7">#{escape(entry['Value7'])}</result>
      <result name="Label8">#{escape(entry['Label8'])}</result>
      <result name="Value8">#{escape(entry['Value8'])}</result>
      <result name="Label9">#{escape(entry['Label9'])}</result>
      <result name="Value9">#{escape(entry['Value9'])}</result>
      <result name="Label10">#{escape(entry['Label10'])}</result>
      <result name="Value10">#{escape(entry['Value10'])}</result>
      <result name="Label11">#{escape(entry['Label11'])}</result>
      <result name="Value11">#{escape(entry['Value11'])}</result>
      <result name="Label12">#{escape(entry['Label12'])}</result>
      <result name="Value12">#{escape(entry['Value12'])}</result>
      <result name="Label13">#{escape(entry['Label13'])}</result>
      <result name="Value13">#{escape(entry['Value13'])}</result>
      <result name="Label14">#{escape(entry['Label14'])}</result>
      <result name="Value14">#{escape(entry['Value14'])}</result>
      <result name="Label15">#{escape(entry['Label15'])}</result>
      <result name="Value15">#{escape(entry['Value15'])}</result>
      <result name="Label16">#{escape(entry['Label16'])}</result>
      <result name="Value16">#{escape(entry['Value16'])}</result>
      <result name="Label17">#{escape(entry['Label17'])}</result>
      <result name="Value17">#{escape(entry['Value17'])}</result>
	  <result name="Label18">#{escape(entry['Label18'])}</result>
      <result name="Value18">#{escape(entry['Value18'])}</result>
      <result name="Label19">#{escape(entry['Label19'])}</result>
      <result name="Value19">#{escape(entry['Value19'])}</result>
      <result name="Label20">#{escape(entry['Label20'])}</result>
      <result name="Value20">#{escape(entry['Value20'])}</result>
	</results>
    RESULTS
	puts(results) if @debug_logging_enabled	
	
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