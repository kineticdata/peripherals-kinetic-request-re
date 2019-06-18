# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class KineticRequestAnswerCreateV5
  
  # The initialize method takes a String of XML.  This XML is defined in the
  # process/node.xml file as the taskDefinition/handler element.  This method
  # should setup (usually retrieve from the input xml) any instance variables
  # that will be used by the handler, validate that the variables are valid, and
  # optionally call a preinitialize_on_first_load method (if there are expensive
  # operations that don't need to be executed with each task node instance).
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_SurveyAnswer','KS_SRV_SurveyQuestion','KS_SRV_CustomerSurvey_base']
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
    
    # Initialize the field values hash
    @field_values = {}
    # For each of the fields in the node.xml file, add them to the hash
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
	 puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()

	 base_entry = get_base_record(@parameters['SubmissionInstanceID'])
	 
    # Retrieve the Question Instance ID from the KS_SRV_SurveyQuestion form using
    # the Question Name and Template Name parameters.
    question_entry = get_question(@parameters['TemplateName'],@parameters['QuestionName'], base_entry['SurveyInstanceID'])
    
	questionValue = @parameters['QuestionValue']
	
	if !questionValue.nil?
					fullAnswer = questionValue[0,3999]
					qlength = questionValue.bytesize
	else
					fullAnswer = questionValue
					qlength = 0
	end
				
    # Set the field_values hash with the Question IID.
    @field_values['QuestionInstanceID'] = question_entry['instanceId']
    @field_values['FullAnswer'] = fullAnswer
	
	puts("Question Length: \n#{qlength}") if @debug_logging_enabled
	if qlength > 4000
					@field_values['UnlimitedAnswer'] = questionValue
	end

	puts("Question Value: \n#{questionValue}") if @debug_logging_enabled
	puts("Full Answer: \n#{fullAnswer}") if @debug_logging_enabled
    
        
    # Update the originating request's Attributes if the Answer value is mapped. We know
    # it's mapped if there is a value in the Answer_FieldMappingID variable.
    if question_entry['Answer_MappingFieldID'] != nil
    
      field_id = question_entry['Answer_MappingFieldID']
     
    
    # Convert the Mapping Field ID to the Field Name
      field_name = @@remedy_forms['KS_SRV_CustomerSurvey_base'].field_for(field_id.to_i).name
    
    # Update the Base Entry's mapped Attribute.
      base_entry.update_attributes!(field_name => @parameters['QuestionValue'])
      
    
    end
    
      
    # Create the entry using the ArsModels form setup the first time this
    # handler is executed.  The :field_values parameter takes a Hash of field
    # names to value mappings (which was built in the #initialize method).  The
    # :fields parameter is an optional Array of field values to return with the
    # entry.  By default (when the :fields parameter is omitted), all field
    # values are returned.  For large forms, the performance gained by
    # specifying a smaller subset of fields can be significant.
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled    
    entry = @@remedy_forms['KS_SRV_SurveyAnswer'].create_entry!(
      :field_values => @field_values
    )
    
    # Return the results
    <<-RESULTS
    <results>
      <result name="Entry Id">#{escape(entry.id)}</result>
    </results>
    RESULTS
  end

  #Retrieve the Question Instance ID from the Template Name and Question Name
  def get_question(template_name, question_name, survey_id)
  
  qual = %|'Survey_Template_Name' = "#{template_name}" AND 'Question' = "#{question_name}" AND 'SurveyInstanceID' = "#{survey_id}"|
  
  entry = @@remedy_forms['KS_SRV_SurveyQuestion'].find_entries(
  	:single,
  	:conditions => [qual],
  	:fields => ['instanceId','Answer_MappingFieldID'])
  
  if entry.nil?
    raise("There was no KS_SRV_SurveyQuestion entry with the qualification #{qual}")
  end
  
  return entry
   
  end
  
  # Get the existing Originating Request record.
  def get_base_record(iid)
  
  qual = %|'179' = "#{iid}"|
  
  entry = @@remedy_forms['KS_SRV_CustomerSurvey_base'].find_entries(
          :single,
          :conditions => [qual],
          :fields => :all)
  
    if entry.nil?
      raise("There was no KS_SRV_CustomerSurvey_base entry with the qualification #{qual}")
    end
  
  
  return entry
  
  end

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries
      @@remedy_context = ArsModels::Context.new(
        :server => get_info_value(input_document, 'server'),
        :username => get_info_value(input_document, 'username'),
        :password => get_info_value(input_document, 'password'),
        :port => get_info_value(input_document, 'port'),
        :prognum => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )

      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end

      # Store that we are preinitialized so that this method is not called a second time
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
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] }
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
    # If the desired element is nil, return nil; otherwise return the text value 
    # of the element
    info_element.nil? ? nil : info_element.text
  end
    
end