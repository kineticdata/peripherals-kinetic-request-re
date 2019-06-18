# Require the necessary standard Ruby libraries
require 'rexml/document'
require 'ars_models'

class KineticRequestSubmissionFormatAnswersHtmlV5

  # Prepare for execution by building the object that represent necessary
  # values, and validating the present state.  This method  sets the following
  # instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
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
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_QuestionAnswerJoin','KS_SRV_CustomerSurvey_base','KS_SRV_SurveyQuestion','KS_ATT_AttributeInstance','KS_SRV_SurveyAnswer','KS_SRV_SurveyAnswerUnlimited']
    )
	
	 # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled
    
	
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end
	
	#lookup Survey ID
	@baseQuery = %|'instanceId' = "#{@parameters['csrvId']}"|
	@base_entry = @@remedy_forms['KS_SRV_CustomerSurvey_base'].find_entries(
	  :first,
	  :conditions => [@baseQuery],
	  :fields     => ['Submit Type','Survey_Template_Name','PageInstanceId','SurveyInstanceID']
	)
	if @base_entry.nil?
		# Raise an exception
		raise "Unable to find base entry to match the indicated base record #{@parameters['csrvId']}"
	end
	
	#search for all the questions
	@fullQuery = %|'SurveyInstanceID' = "#{@base_entry['SurveyInstanceID']}"|
	puts @fullQuery
	@question_entries = @@remedy_forms['KS_SRV_SurveyQuestion'].find_entries(
      :all,
      :conditions => [@fullQuery],
	  :order => ['Question_Order'],
      :fields     => ['Question', 'Question_Order']
    )
	
	@surveyID = ""
    # Retrieve all of the questions
    questions = {}
	@question_entries.each do |a|
		questions[a['Question']] = a['Question_Order']
		puts("Found Question: \n#{a['Question']}") if @debug_logging_enabled
	end
    #REXML::XPath.match(@input_document, '/handler/questions/answer').each do |node|
    #  questions[node.attribute('name').value] = node.text.to_s
    #end

    # Retrieve the list of keys, this is used to 
    menu_labels = questions.keys
	
	#lookup starting and ending Indexes

    # If a starting question menu label was not provided
    if @parameters['start'].empty?
      # Use the first question as the starting point
      starting_index = 0
      # If a starting question menu label was provided
    else
      # Use the index of the provided question as the starting point
      starting_index = menu_labels.index(@parameters['start'])
      # If there is not a question matching the provided menu label
      if starting_index.nil?
        # Raise an exception
        raise "The submission does not include a question with a question name " <<
          "matching the 'Starting Question' parameter."
      end
    end

    # If a ending question menu label was not provided
    if @parameters['end'].empty?
      # Use the last question as the ending point
      ending_index = menu_labels.length - 1
      # If a ending question menu label was provided
    else
      # Use the index of the provided question as the ending
      ending_index = menu_labels.index(@parameters['end'])
      # If there is not a question matching the provided menu label
      if ending_index.nil?
        # Raise an exception
        raise "The submission does not include a question with a question name " <<
          "matching the 'Ending Question' parameter."
      end
    end

    # Build a list of included and excluded questions by splitting the comma
    # separated parameters.
    includes = @parameters['include'].split(',')
    excludes = @parameters['exclude'].split(',')

    # Initialize the @questions hash, this will contain all of the question menu
    # label to answer values of the questions matching the parameter
    # configuration.
    @questions = {}

    # For each of the selected menu labels
    menu_labels.each_with_index do |menu_label, index|
      # If the current menu label exists in the exclude list
      if excludes.include?(menu_label)
        # Continue to the next menu label
        next
      end

      # If the current menu label exists in the include list
      if includes.include?(menu_label)
        # Add the question/answer to the @questions Hash
        @questions[menu_label] = questions[menu_label]
        # Continue to the next menu label.
        next
      end

      # If the current menu label exists somewhere between the starting and
      # ending question (inclusively).
      if index >= starting_index && index <= ending_index
        # Add the question/answer to the @questions Hash
        @questions[menu_label] = questions[menu_label]
      end
    end
	
	puts @questions.inspect
	
	#create search string for label/order pairs for the questions to be included
	@query = %|'CustomerSurveyInstanceID\' = "#{@parameters['csrvId']}" AND (|
	@query << @questions.collect {|name, order|
		%|'Question' = "#{name}"|
	}.join(" OR ")
	@query << ")"
	@query.gsub!('?', '\?')
	
	puts("Query: \n#{@query}") if @debug_logging_enabled
	
  	#do search for label/answer pairs for the desired questions
	@question_answer_entries = @@remedy_forms['KS_SRV_QuestionAnswerJoin'].find_entries(
      :all,
      :conditions => [@query],
	  :order => ['Question_Order'],
      :fields     => ['QuestionLabel','FullAnswer', 'Question', 'QuestioninstanceId']
    )
  end

  # Builds and returns the results of interpreting the desired template String
  # within the current context (IE exposing the @answers variable).
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An HTML formatted String representing the return variable results.
  def execute()
	
	 
	if (@parameters['template'] == "Yes") 
		result= "<h2>" +@base_entry['Survey_Template_Name'] +"</h2>"
	else
		result= ""
	end
	result << "\n" << @parameters['h_table_structure']
	result << "\n" << @parameters['q_table_wrapper_open']
	result << "\n" << @parameters['q_tbody_wrapper_open']

	if (@parameters['template'] == "Yes") 
		textresult = "Answers for " +@base_entry['Survey_Template_Name'] +":\n"
	else
		textresult = "Answers:\n"
	end
	@question_answer_entries.each do |entry|
		# Get the question label.  Note that if the question label is nil we will use
		# the question name which cannot be nil.
		label = entry['QuestionLabel'] || entry['Question']
		
		@answer = entry['FullAnswer']
		if !@answer.nil?
			 answerQual = %|'700001850' = "#{@parameters['csrvId']}" AND '700001890' = "#{entry['QuestioninstanceId']}"|
			 answer_entry = @@remedy_forms['KS_SRV_SurveyAnswer'].find_entries(
			  :single,
			  :conditions => [answerQual],
			  :fields     => :all
			)
			
			if !answer_entry['Unlimited Answer Id'].nil?
				unlimited_answer_entry = @@remedy_forms['KS_SRV_SurveyAnswerUnlimited'].find_entries(
				  :single,
				  :conditions => [answerQual],
				  :fields     => :all
				)
				
				if !unlimited_answer_entry.nil?
					@answer = unlimited_answer_entry['UnlimitedlAnswer']
				end
			end
			
		end
		
		# Build the table row html code for the current question answer entry.
		result << "\n" << @parameters['q_tr_wrapper_open']
		result << "\n" << @parameters['q_td_qlabel_wrapper_open']
		#result << "\n" << label << ":"
		result << "\n" << escape_html(label) << ""
		result << "\n" << @parameters['q_td_qlabel_wrapper_close']
		result << "\n" << @parameters['q_td_qanswer_wrapper_open']
		result << "\n" << escape_html(@answer)
		result << "\n" << @parameters['q_td_qanswer_wrapper_close']
		result << "\n" << @parameters['q_tr_wrapper_close']

		# Build the plain text line for the current question answer entry.
		textresult << "#{label}: #{@answer}\n"
	end
	
	result << "\n" << @parameters['q_tbody_wrapper_close']
	result << "\n" << @parameters['q_table_wrapper_close']
	
	link = ""
	if (@parameters['link'] == "Yes")
		#search for all the questions
		@linkQuery = %|'Attribute_Parent_InstanceId' = "#{@base_entry['SurveyInstanceID']}" AND 'Attribute Type Name' = "Review JSP"|
		@attribute_entry = @@remedy_forms['KS_ATT_AttributeInstance'].find_entries(
		  :first,
		  :conditions => [@linkQuery],
		  :fields     => ['Character_Value']
		)
	
		link = @parameters['webServer']+"ReviewRequestPage?csrv="+@parameters['csrvId']+"&pageInstanceID="+@base_entry['PageInstanceId']
		
		if !@attribute_entry.nil?
			link = link + "&reviewPage=" + 	@attribute_entry['Character_Value']
		end
	result << "\n<br>" << link
	textresult << "\n" << link
	end
	
	
	puts("Results: \n#{result}") if @debug_logging_enabled
	puts("Text Results: \n#{textresult}") if @debug_logging_enabled
	
    # Return the results String
    <<-RESULTS
    <results>
      <result name="result">#{escape(result)}</result>
	  <result name="textresult">#{escape(textresult)}</result>
    </results>
    RESULTS
  end

  ###############################################################################
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


  def escape_html(string)
    # Globally replace characters based on the ESCAPE_HTML constant
    string.to_s.gsub(/[&"><'\/\\\s\r\n#]/) { |special| ESCAPE_HTML[special] } if string
  end
ESCAPE_HTML = {
      "&" => "&amp;",
      "<" => "&lt;",
      ">" => "&gt;",
      "'" => "&#39;",
      '"' => "&quot;",
      "/" => "&#47;",
	  "#" => "&#35;",
	  " " => "&nbsp;",
	  "\\" => "&#92;",
	  "\r" => "<br>",
	  "\n" => "<br>"
	  
    }
  end