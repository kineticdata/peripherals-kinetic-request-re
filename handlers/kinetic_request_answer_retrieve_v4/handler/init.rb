# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class KineticRequestAnswerRetrieveV4
  
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
      ['KS_SRV_SurveyAnswer','KS_SRV_SurveyQuestion','KS_SRV_SurveyAnswerUnlimited','KS_SRV_CustomerSurvey_base']
    )
	
	 # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()
 	base_entry = get_base_record(@parameters['SubmissionInstanceID'])
	
    # Get the Question entry associated with the Question Name and Template Name
    question_entry = get_question(@parameters['TemplateName'],@parameters['QuestionName'], base_entry['SurveyInstanceID'])
	  
    # Retrieve the KS_SRV_SurveyAnswer value for the specified Request and Question.
    
    qual = %|'700001890' = "#{question_entry['instanceId']}" AND '700001850' = "#{@parameters['SubmissionInstanceID']}"|
    
    entry = @@remedy_forms['KS_SRV_SurveyAnswer'].find_entries(
      :single,
      :conditions => [qual],
      :fields => :all
      #:all
      )
    
    # Check if there was an answer value returned. If no Answer was found, we return nil
    # rather than throw an error as this allows us to accommodate a nil record at run time.
    if entry.nil?
      answer_value = ""
    else
	  if entry['FullAnswer'].nil?	
		answer_value = escape(entry['FullAnswer'])
	  elsif entry['FullAnswer'].bytesize < 3998
		answer_value = escape(entry['FullAnswer'])
	  else
		entryUnlimited = @@remedy_forms['KS_SRV_SurveyAnswerUnlimited'].find_entries(
		  :single,
		  :conditions => [qual],
		  :fields => :all
		  #:all
		  )
		if entryUnlimited.nil?
			answer_value = escape(entry['FullAnswer'])
		else
			answer_value = escape(entryUnlimited['UnlimitedlAnswer'])
		end
	  end
    end      
    
	puts("Returning #{answer_value}.") if @debug_logging_enabled
    # Return the results
    results = <<-RESULTS
    <results>
      <result name="Value">#{answer_value}</result>
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