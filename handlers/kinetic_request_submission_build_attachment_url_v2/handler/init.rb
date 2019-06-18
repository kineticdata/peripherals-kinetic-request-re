# Require the necessary standard Ruby libraries and ars models
require 'rexml/document'
require 'uri'
require 'ars_models'

class KineticRequestSubmissionBuildAttachmentUrlV2
  # Prepare for execution by building the objects that represent necessary
  # values, and validating the present state.  This method  sets the following
  # instance variables:
  # * @input_document - A REXML::Document object that represents the input XML.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of XML that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document, ['KS_SRV_SurveyQuestion', 'KS_SRV_QuestionAnswerJoin']
    )
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  # Builds a download URL for the attachment file that was the answer to the specified
  # question on the current submission.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML formatted String representing the return variable results.
  def execute()
    # Retrieve the KS_SRV_SurveyQuestion record for the given question menu label
    # and the current survey template instance id.
    survey_question_entry = @@remedy_forms['KS_SRV_SurveyQuestion'].find_entries(
      :single,
      :fields     => ['instanceId'],
      :conditions => [%|'Editor Label' = "#{@parameters['question_menu_label']}" AND | <<
          %|'SurveyInstanceID' = "#{@parameters['survey_template_instance_id']}"|]
    )
    if survey_question_entry.nil?
      raise "No question was found with the specified label \"#{@parameters['question_menu_label']}\""
    end
    
    # Retrieve the KS_SRV_QuestionAnswerJoin record for the given question and the 
    # current submission.
    question_answer_entry = @@remedy_forms['KS_SRV_QuestionAnswerJoin'].find_entries(
      :single,
      :fields     => ['FullAnswer'],
      :conditions => [%|'QuestioninstanceId' = "#{survey_question_entry['instanceId']}" AND | <<
          %|'CustomerSurveyInstanceID' = "#{@parameters['customer_survey_instance_id']}"|]
    )
    
    # If there is no record on KS_SRV_QuestionAnswerJoin, the question was not answered
    # and we will return an empty string.  Otherwise, we will build the HTML link
    # from all of the data that was input and retrieved by this handler.
    if question_answer_entry.nil?
      file_name = ""
      url = ""
    else
      file_name = question_answer_entry['FullAnswer']
      url = %|SimpleDataRequest| <<
        %|?requestName=getFile| <<
        %|&dataRequestId=existingAttachment| <<
        %|&sessionId=#{encode_url_parameter(@parameters['customer_survey_instance_id'])}| <<
        %|&questionId=#{encode_url_parameter(survey_question_entry['instanceId'])}| <<
        %|&fileName=#{encode_url_parameter(question_answer_entry['FullAnswer'])}| <<
        %|&noCache=#{encode_url_parameter(Time.now.to_i)}|
    end    

    # Return the results String
    <<-RESULTS
    <results>
      <result name="URL">#{escape(url)}</result>
      <result name="File Name">#{escape(file_name)}</result>
    </results>
    RESULTS
  end
  
  ##############################################################################
  # Handler helper functions
  ##############################################################################
  
  # Escapes the String parameter, replacing all URL-unsafe character with their
  # associated character codes.
  #
  # For example:
  #   URI.escape(
  #     'Hash#-Ampersand&-Equals=-Slash/-Backslash\\',
  #     Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
  #   )
  # will result in:
  #   "Hash%23-Ampersand%26-Equals%3D-Slash%2F-Backslash%5C"
  def encode_url_parameter(string)
    URI.escape(string.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
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
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
