require 'rexml/document'

class KineticRequestCheckboxToXmlV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      # Associate the attribute name to the String value (stripping leading and
      # trailing whitespace)
      @parameters[node.attribute('name').value] = node.text.to_s.strip
    end
  end

  def execute()
    answers = @parameters['input'].split(', ')
    xml = convert_to_xml(answers)
    
    # Initialize the REXML formatter.  Also set the compact attribute to true, this
    # will result in no new lines for text within XML elements when printed.
    @formatter = REXML::Formatters::Pretty.new
    @formatter.compact = true
    # format the xml output string
    string = @formatter.write(xml, "")

    <<-RESULTS
    <results>
      <result name="XML">#{escape(string)}</result>
    </results>
    RESULTS
  end

  # This method converts a Ruby Array to an REXML::Element object.  The REXML::Element
  # that is returned is the root node of the XML structure and all of the resulting
  # XML data will be nested within that single element.
  def convert_to_xml(array)
    element = REXML::Element.new("list")
    array.each do |item|
      list_element = REXML::Element.new("item")
      list_element.add_text(item)
      element.add_element(list_element)
    end
    element
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

end