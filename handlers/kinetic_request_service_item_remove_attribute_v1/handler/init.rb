require 'rexml/document'
require 'ars_models'

class KineticRequestServiceItemRemoveAttributeV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_SurveyTemplate', 'KS_ATT_AttributeInstance']
    )
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  def execute()
    # Query to retrieve the service item record.  The instanceId of the service
    # item record will be used to query the attribute form.  If there is no record
    # return by this query we raise an exception.
    service_item_qualification = [
      %|'Category' = "#{@parameters['catalog_name']}"|,
      %|'Survey_Template_Name' = "#{@parameters['service_item_name']}"|
    ].join(" AND ")
    service_item_entry = @@remedy_forms['KS_SRV_SurveyTemplate'].find_entries(
      :single, 
      :conditions => [service_item_qualification],
      :fields => ['instanceId']
    )
    if service_item_entry.nil?
      raise(%|Could not find service item named "#{@parameters['service_item_name']} | <<
          %|in the catalog "#{@parameters['catalog_name']}"|)
    end

    # Query the attribute instance form with the specified attribute name and the
    # instanceId of the service item record.  If no attribute records are returned
    # we raise an exception.  If attribute records are returned we delete all of
    # them.
    attribute_qualification = [
      %|'Attribute Type Name' = "#{@parameters['attribute_name']}"|,
      %|'Attribute_Parent_InstanceId' = "#{service_item_entry['instanceId']}"|
    ].join(" AND ")
    attribute_entries = @@remedy_forms['KS_ATT_AttributeInstance'].find_entries(
      :all,
      :conditions => [attribute_qualification],
      :fields => []
    )
    if attribute_entries.empty?
      raise(%|Attribute "#{@parameters['attribute_name']}" is not defined for serivce | <<
          %|item "#{@parameters['service_item_name']}" in catalog "#{@parameters['catalog_name']}"|)
    end
    attribute_entries.each {|entry|
      entry.delete!
    }

    # Build and return the results string returned by this handler.
    <<-RESULTS
    <results>
    </results>
    RESULTS
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
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end