# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestSubmissionCreateAnswersV3
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(@input_document,[
        'KS_SRV_CustomerSurvey_base',
        'KS_SRV_SurveyQuestion',
        'KS_SRV_SurveyAnswer'
      ])

	  # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled
	
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  def execute()
    # Retrieve the specified submission record.  If none was returned raise an
    # exception.
    submission = @@remedy_forms['KS_SRV_CustomerSurvey_base'].find_entries(
      :single,
      :conditions => [%|'instanceId'="#{@parameters['submission_instance_id']}"|],
      :fields       => ['LookupValueId', 'instanceId','SurveyInstanceID','CustomerSessionInstanceID']
    )
    if submission.nil?
      raise "Could not find Submission with instanceId of '#{@parameters['submission_instance_id']}'"
    end
    # Ensure that the lookup value id is equal to the submission's instance id.
    # This is done so that answers are loaded correctly when this submission is
    # opened.
    if submission['LookupValueId'] != submission['instanceId']
      submission.update_attributes!({'LookupValueId' => submission['instanceId']})
    end

    # Convert the Answer Sets parameter to a JSON object.  Then iterate through
    # each set, merging the answers.  Note that if there are duplicates, answers
    # defined later will overwrite earlier ones.
    answer_sets =  JSON.parse("[#{@parameters['answer_sets']}]")
    combined_answer_set = answer_sets.inject({}) {|result, answer_set| result.merge(answer_set)}

    # Retrieve all of the questions related to the template.  Then create an
    # answer record for any question that has an answer defined in the
    # combined_answer_set hash.  Note that we do not create an answer record if
    # the answer is nil or an empty string.
    questions = @@remedy_forms['KS_SRV_SurveyQuestion'].find_entries(
      :all,
      :fields => ['Editor Label', 'instanceId', 'FieldMapNumber', 'Answer Mapping'],
      :conditions => [%|'SurveyInstanceID'="#{submission['SurveyInstanceID']}"|]
    )
    questions.each do |question|
      if combined_answer_set.has_key?(question['Editor Label'])
        answer = combined_answer_set[question['Editor Label']]
        unless (answer.nil? || (answer.is_a?(String) && answer.empty?))
         if answer.bytesize <= 4000
			  @@remedy_forms['KS_SRV_SurveyAnswer'].create_entry!(:field_values => {
					'AnswerViewer'              => answer[0,254],
					'FullAnswer'                => answer,
					'CustomerSurveyInstanceID'  => submission['instanceId'],
					'QuestionInstanceID'        => question['instanceId'],
					'CustomerSessionInstanceID' => submission['CustomerSessionInstanceID']
			  })
		  else
			  @@remedy_forms['KS_SRV_SurveyAnswer'].create_entry!(:field_values => {
					'AnswerViewer'              => answer[0,254],
					'FullAnswer'                => answer[0,3999],
					'UnlimitedAnswer'           => answer,
					'CustomerSurveyInstanceID'  => submission['instanceId'],
					'QuestionInstanceID'        => question['instanceId'],
					'CustomerSessionInstanceID' => submission['CustomerSessionInstanceID']
			  })
		  end
        end
      end
    end

    # Return the results String
    return "<results/>"
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