require 'rexml/document'
require 'ars_models'

class KappAssignmentGroupMembershipLookupV1
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
    preinitialize_on_first_load(
      @input_document,
      [
        'KAPP_Assignment_Group',
        'KAPP_Assignment_GroupAssoc_Lookup', 'KAPP_Assignment_People'
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
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled
  end
  
  # Retrieves a record from CTM:People using the remedy_login_id parameter.  If
  # there is an alternate approval assigned, it retrives the CTM:People record 
  # associated to the alternate approver's remedy login id.  Alternate approvers
  # are determinded using the get_approver() helper function.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.  
  def execute()
  
    email_list = ''
	member_list = '<membership>'
  
	if (@parameters['assignee_id'])
		entry = @@remedy_forms['KAPP_Assignment_People'].find_entries(
		  :single,
		  :conditions => [%|'Login ID' = "#{@parameters['assignee_id']}" |],
		  :fields => ['Email']
		)
		email_list << entry['Email']
		member_list << '<member>'+ @parameters['assignee_id'] + '</member>'
	
	elsif (@parameters['support_group_id'])
	
		entry_list = @@remedy_forms['KAPP_Assignment_GroupAssoc_Lookup'].find_entries(
		  :all,
		  :conditions => [%|'Group ID' = "#{@parameters['support_group_id']}" |],
		  :fields => ['Login ID']
		)
		raise "No matching entries in the CTM:Support Group Association form for the given support group [#{@parameters['support_group_id']}]" if entry_list.nil?
		
		# Build array containing the a list of approvers related to the Remedy support group
		# While excluding the requested by and requested for individuals    
		entry_list.each do |userid|
			entry = @@remedy_forms['KAPP_Assignment_People'].find_entries(
			  :single,
			  :conditions => [%|'Login ID' = "#{userid['Login ID']}" |],
			  :fields => ['Email']
			)
			if !entry.nil?
				if !entry['Email'].nil?
					email_list << entry['Email']+','
				end
			end
			if !userid['Login ID'].nil?
				member_list << '<member>'+ userid['Login ID'] + '</member>'
			end
		end      
	
		email_list = email_list.chomp(',')
    end
	
	member_list = member_list+'</membership>'
	
	puts("Results: email list: #{escape(email_list)}\n membership list: #{escape(member_list)}") if @debug_logging_enabled
	
    <<-RESULTS
    <results>
      <result name="Email List">#{escape(email_list)}</result>
	  <result name="Membership List">#{escape(member_list)}</result>
    </results>
    RESULTS
    
 
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