# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticRequestSubmissionGetAnswerSetV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve parameters from the input xml and store them as instance
    # variables available to the rest of this execution.
    @mode = get_parameter_value(@input_document, 'mode')
    @included_questions = get_parameter_value(@input_document, 'included_questions')
    @excluded_questions = get_parameter_value(@input_document, 'excluded_questions')
    @question_aliases = get_parameter_value(@input_document, 'question_aliases')

    # Retrieve all of the question answer pairs and store them in a hash.
    @answers = {}
    REXML::XPath.match(@input_document, '/handler/answers/answer').each do |node|
      @answers[node.attribute('name').value] = node.text.to_s
    end
  end

  def execute()
    # Determine the question labels to be used based on the mode (All or Some).
    # If 'All' then the question labels will simply be every key in the answers
    # hash.  If 'Some' then the question labels are determined by the included
    # questions parameter.  If something else raise an exception.
    if @mode == 'All'
      question_labels = @answers.keys
    elsif @mode == 'Some'
      question_labels = @included_questions.to_s.split(',')
    else
      raise "Invalid value for 'Mode' parameter: #{@mode}.  Valid values are 'All' or 'Some'."
    end

    # Subtract the questions in the excluded questions array from the question
    # labels to be used.
    question_labels = question_labels - @excluded_questions.to_s.split(',')

    # Build the alias hash by first splitting the question aliases string on a
    # comma.  Then split each of these string mappings by an equals sign.  If
    # the string was formatted correctly this should result in exactly two
    # elements, if not raise an exception.
    alias_hash = @question_aliases.to_s.split(',').inject({}) do |result, mapping|
      split_mapping = mapping.split('=')
      unless split_mapping.size == 2
        raise "Invalid 'Question Alias' string: #{@question_aliases}"
      end
      result.merge({split_mapping.first => split_mapping.last})
    end

    # Iterate through the array of question labels and build the output hash.
    # Note that we check the alias hash for question label aliases to use while
    # building the output hash.  This is the hash that will be converted to a 
    # JSON string and returned.
    output = {}
    question_labels.each do |question_label|
      if alias_hash.member?(question_label)
        output[alias_hash[question_label]] = @answers[question_label]
      else
        output[question_label] = @answers[question_label]
      end
    end

    # Build and return the output XML string.
    <<-RESULTS
    <results>
        <result name="Answer Set">#{escape(output.to_json)}</result>
    </results>
    RESULTS
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
  def get_parameter_value(document, name)
    # Retrieve the XML node representing the desird info value
    parameter_element = REXML::XPath.first(document, "/handler/parameters/parameter[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    parameter_element.nil? ? nil : parameter_element.text
  end
end