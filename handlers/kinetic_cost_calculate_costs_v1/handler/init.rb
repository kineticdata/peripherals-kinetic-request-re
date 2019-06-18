require 'rexml/document'
require 'ars_models'

class KineticCostCalculateCostsV1
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
	# Check for existing KS_SRV_Helper entry.
    entry = @@remedy_forms['KS_SRV_Helper'].find_entries(
      :all,
      :conditions => [%|'Index Field1' = "Kinetic Cost" and 'Index Field2' = "#{@parameters['CostCategory']}"|],
      :fields => ['Character Field1','Character Field2','Character Field3','Character Field4']
    )
    if entry.nil?
      raise(%|A Cost entry can't be found in KS_SRV_Helper|)
    end
	
	costs_by_question_answer = {}
	answers = {}
	total_cost = 0
	
	#Create an object to represent the costs
	#formatted as: "{"chkbox_accessory_power_cable":{"Docking Station":{"value":"10.905"},"Laptop":{"value":"5"}},"chkbox_accessory_network_cable":{"CISCO Phone Cable":{"value":"5","qty_qstn":"accessory_network_cables"},"10 ft Network Cable":{"value":"7","qty_qstn":"accessory_network_cables"}}}"
	
	
	
	entry.each do |entry|
		qstn_details_obj = {}
		qstn_details_obj['value'] = entry['Character Field3']
					
		if entry['Character Field4']
			qstn_details_obj['qty_qstn'] = entry['Character Field4']
		end	
		
		if costs_by_question_answer[entry['Character Field1']].nil?
			costs_by_question_answer[entry['Character Field1']] = {}
		end
		costs_by_question_answer[entry['Character Field1']][entry['Character Field2']] = qstn_details_obj
	end
	puts("Cost Results: #{costs_by_question_answer.inspect}") if @debug_logging_enabled
	
	# Retrieve all of the answers
    REXML::XPath.match(@input_document, '/handler/answers/answer').each do |node|
      answers[node.attribute('name').value] = node.text.to_s
    end
	puts("answers: #{answers.inspect}") if @debug_logging_enabled
	
	#Iterate through the questions of the submission
	answers.each do |question, value|
		# If there is a price spec for the current question.
		if value != "" and costs_by_question_answer[question]
			qstn_details_obj = costs_by_question_answer[question]
			value_array = value.split(', ');
			# Iterate through selected values (could be multiple for check boxes).
			value_array.each do |v|
				# If there is a price defined for the currents question's value.
				if !costs_by_question_answer[question][v].nil? and costs_by_question_answer[question][v]['value'] and !costs_by_question_answer[question][v]['qty_qstn']
					puts("Adding $#{costs_by_question_answer[question][v]['value']} to the total for question: #{question} for a #{v}") if @debug_logging_enabled
					total_cost += costs_by_question_answer[question][v]['value'].to_f
				elsif !costs_by_question_answer[question][v].nil? and costs_by_question_answer[question][v]['value'] and costs_by_question_answer[question][v]['qty_qstn']
					qty = answers[costs_by_question_answer[question][v]['qty_qstn']].to_f
					if qty > 0
						item_cost = costs_by_question_answer[question][v]['value'].to_f * qty
						total_cost += item_cost
						puts("Adding $#{item_cost} to the total for question: #{question} for #{qty} #{v}s at $#{costs_by_question_answer[question][v]['value']} each") if @debug_logging_enabled
					end
				end
				puts("Running total is: $#{total_cost}")
			end
		end
		

	end
	
	
 
	
	total_cost = sprintf('%.2f', total_cost)
	puts("Total Cost = #{total_cost}")
	
    # Build the results to be returned by this handler
    results = <<-RESULTS
    <results>
      <result name="Total">#{escape(total_cost)}</result>
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
