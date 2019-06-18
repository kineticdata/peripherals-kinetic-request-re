# Require the necessary standard Ruby libraries
require 'rexml/document'
require 'uri'

class KineticRequestSubmissionBuildReviewRequestUrlV2
  # Prepare for execution by building the object that represent necessary
  # values, and validating the present state.  This method  sets the following
  # instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @configurations - A Hash of configuration names to configuration values.
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

    # Store the configuration parameters in the node.xml in a hash attribute
    # named @configurations.
    @configurations = {}
    REXML::XPath.match(@input_document, '/handler/configuration/config').each do |node|
      @configurations[node.attribute('name').value] = node.text
    end
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
  end

  # Builds the URL string by concatenating the application path, review request
  # Servlet path, and a query string build from the configured parameter names
  # and encoded parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # If we are using the simple review request configuration
    if @configurations['configuration_type'] == 'Simple'
      # Encode the csrv, this will ensure that any '#' characters in the
      # InstanceId are escaped.
      csrv = encode_url_parameter(@parameters['csrv'])
      # Concatenate the application path, review request Servlet path, and the
      # encoded InstanceId of the desired submission
      url = "#{@configurations['application_path']}ReviewRequest?csrv=#{csrv}"
      # If we are using the advanced review request configuration
    else
      # Build up the HTTP parameter name/value pair Strings
      parameter_strings = @parameters.collect {|name, value|
        # Each parameter pair String maps the parameter to the encoded parameter
        # value.  It is important to encode the value so that special characters
        # (such as '#' or '&') don't modify the intended meaning of the URL.
        "#{name}=#{encode_url_parameter(value)}" unless value.nil?
      }.compact

      # Build up the URL
      url = "#{@configurations['application_path']}ReviewRequest?#{parameter_strings.join('&')}"
    end

    # Return the results String
    <<-RESULTS
    <results>
      <result name="URL">#{escape(url)}</result>
    </results>
    RESULTS
  end

  ##############################################################################
  # Handler utility functions
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
end
