# Require the necessary standard Ruby libraries
require 'erb'
require 'rexml/document'

class KineticRequestSubmissionFormatAnswersV1
  # Defines the default ERB template to be used to generate the result
  DEFAULT_TEMPLATE = <<-TEMPLATE
Answers:
<% @answers.each do |name,answer| %>
  <%= name %>: <%= answer %>
<% end %>
  TEMPLATE


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

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    # Retrieve all of the answers
    answers = {}
    REXML::XPath.match(@input_document, '/handler/answers/answer').each do |node|
      answers[node.attribute('name').value] = node.text.to_s
    end

    # Retrieve the list of keys, this is used to 
    menu_labels = answers.keys

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
        raise "The submission does not include a question with a menu label " <<
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
        raise "The submission does not include a question with a menu label " <<
          "matching the 'Ending Question' parameter."
      end
    end

    # Build a list of included and excluded questions by splitting the comma
    # separated parameters.
    includes = @parameters['include'].split(',')
    excludes = @parameters['exclude'].split(',')

    # Initialize the @answers hash, this will contain all of the question menu
    # label to answer values of the questions matching the parameter
    # configuration.
    @answers = {}

    # For each of the selected menu labels
    menu_labels.each_with_index do |menu_label, index|
      # If the current menu label exists in the exclude list
      if excludes.include?(menu_label)
        # Continue to the next menu label
        next
      end

      # If the current menu label exists in the include list
      if includes.include?(menu_label)
        # Add the question/answer to the @answers Hash
        @answers[menu_label] = answers[menu_label]
        # Continue to the next menu label.
        next
      end

      # If the current menu label exists somewhere between the starting and
      # ending question (inclusively).
      if index >= starting_index && index <= ending_index
        # Add the question/answer to the @answers Hash
        @answers[menu_label] = answers[menu_label]
      end
    end
  end

  # Builds and returns the results of interpreting the desired template String
  # within the current context (IE exposing the @answers variable).
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Determine which template should be used to format the answers
    template_string = DEFAULT_TEMPLATE

    # Attempt to build the result
    begin
      # Initialize a new ERB template from the
      template = ERB.new(template_string, nil, '<>')
      # Overwrite the template filename for help with debugging.  This will
      # prefix any error backtraces with (Format Template) rather than the more
      # ambiguous (erb).
      template.filename = "(Format Template)"
      # Use the current binding (which represents the Ruby context to execute
      # the template within).  By setting it to the binding of this method, it
      # will have access to the @answers variables generated in the initialize
      # method.
      result = template.result(binding)
      # If there was a problem building the result
    rescue Exception
      # Output the error in a clean, easy to interpret manner
      puts "A problem was encountered executing the formatting template:\n" <<
        "  Format Template:\n#{template_string.gsub(/^/,'    ')}\n" <<
        "  Backtrace:\n    #{$!.message}\n    #{$!.backtrace.join("\n    ")}"
    end

    # Return the results String
    <<-RESULTS
    <results>
      <result name="result">#{escape(result)}</result>
    </results>
    RESULTS
  end

  ###############################################################################
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
