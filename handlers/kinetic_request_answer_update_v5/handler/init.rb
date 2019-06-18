# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class KineticRequestAnswerUpdateV5
  
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
    
    @field_values = {}
	@update_values = {}
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()
  
	base_entry = get_base_record(@parameters['SubmissionInstanceID'])
	
    # Get the Question entry associated with the Question Name and Template Name
    question_entry = get_question(@parameters['TemplateName'],@parameters['QuestionName'], base_entry['SurveyInstanceID'])
	
	# Set the field_values hash with the Question IID.
	@field_values['CustomerSurveyInstanceID'] = @parameters['SubmissionInstanceID']
    @field_values['QuestionInstanceID'] = question_entry['instanceId']
    @field_values['FullAnswer'] = @parameters['QuestionValue']
    @field_values['AnswerViewer'] = @parameters['QuestionValue'][0..254]
	
	unlimitedAnswer=false
	if @parameters['QuestionValue'].bytesize > 4000
		puts("Answer > 4000 bytes.") if @debug_logging_enabled
		unlimitedAnswer=true
		@field_values['FullAnswer'] = @parameters['QuestionValue'][0..3999]
		@field_values['UnlimitedAnswer'] = @parameters['QuestionValue']
	end
	
    # Update the originating request's Attributes if the Answer value is mapped. We know
    # it's mapped if there is a value in the Answer_FieldMappingID variable.
    if question_entry['Answer_MappingFieldID'] != nil
        
      field_id = question_entry['Answer_MappingFieldID']
      base_entry = get_base_record(@parameters['SubmissionInstanceID'])
        
    # Convert the Mapping Field ID to the Field Name
      field_name = @@remedy_forms['KS_SRV_CustomerSurvey_base'].field_for(field_id.to_i).name
       
    # Update the Base Entry's mapped Attribute.
      base_entry.update_attributes!(field_name => @field_values['AnswerViewer'])
            
    end
  
    # Find and update the Answer entry. 
    
    qual = %|'QuestionInstanceID' = "#{question_entry['instanceId']}" AND 'CustomerSurveyInstanceID' = "#{@parameters['SubmissionInstanceID']}"|
    
    @entry = @@remedy_forms['KS_SRV_SurveyAnswer'].find_entries(
      :single,
      :conditions => [qual],
      :fields => :all
      )
    
    if @entry.nil?
		puts("Did not find answer, Creating Answer.") if @debug_logging_enabled
      @entry = @@remedy_forms['KS_SRV_SurveyAnswer'].create_entry!(
      :field_values => @field_values
		)
	else
		puts("Found answer, Updating Answer.") if @debug_logging_enabled
		if (unlimitedAnswer)
			@entry.update_attributes!({'UnlimitedAnswer' =>  @field_values['UnlimitedAnswer'],'FullAnswer' =>  @field_values['FullAnswer'], 'AnswerViewer' => @field_values['AnswerViewer']})
		else
			@entry.update_attributes!({'FullAnswer' =>  @field_values['FullAnswer'], 'AnswerViewer' => @field_values['AnswerViewer']})
		end
	end
	
    
    # Return the results
    results = <<-RESULTS
    <results>
      <result name="Value">#{escape(@entry['AnswerViewer'])}</result>
	  <result name="Entry Id">#{escape(@entry.id)}</result>
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

  # Get the existing Answer record.
  def get_answer(question_iid, survey_iid)
  
  qual = %|'QuestionInstanceID' = "#{question_iid}" AND 'CustomerSurveyInstanceID' = "#{survey_iid}"|
  
  entry = @@remedy_forms['KS_SRV_SurveyAnswer'].find_entries(
          :single,
          :conditions => [qual],
          :fields => :all)
  
    if entry.nil?
      raise("There was no KS_SRV_SurveyAnswer entry with the qualification #{qual}")
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