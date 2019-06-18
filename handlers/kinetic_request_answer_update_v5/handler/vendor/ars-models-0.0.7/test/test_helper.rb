require 'test/unit'
require 'yaml'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'init'))

class Test::Unit::TestCase
  # Simulate automatic loading similar to Rails fixtures.  All '*.yml' files
  # located in the test/config directory will be loaded and stored in the
  # FIXTURES contant.
  #
  # Fixtures can be accessed via the FIXTURES constant using the symbolized name
  # of the file.  See below for an example.
  #
  # # Contents of context.yml:
  #    :admin_user:
  #      :adapter: 'japi'
  #      :server: '209.98.36.43'
  #      :timezone: '-05:00'
  #      :username: 'Demo'
  #
  # # Within any of the tests:
  #   FIXTURES[:context][:admin_user:] # {:adapter => 'japi', :server => '209.98.36.43', :timezone => '-05:00', :username => 'Demo'}
  FIXTURES = Dir[File.join(File.dirname(__FILE__), 'config', '*.yml')].inject({}) do |hash, config_file|
    hash[File.basename(config_file, '.yml').to_sym] = YAML::load(IO.read(config_file))
    hash
  end

  # Set the context
  context_user_key = ENV['CONTEXT'] ? ENV['CONTEXT'].to_sym : :admin_user
  AdminContext = ArsModels::Context.new(FIXTURES[:context][context_user_key])

  # Set the ars models constants
  InternalError = ArsModels::Exceptions::InternalError
  ModelException = ArsModels::Exceptions::ModelException
  
  Context = ArsModels::Context
  Field = ArsModels::Field

  Entry = ArsModels::Entry.context_instance(AdminContext)
  Form = ArsModels::Form.context_instance(AdminContext)
  
  # Find the forms
  missing_forms = []
  ['CanonicalForm', 'DefaultForm', 'DefaultFormWithDefaults', 'MessageForm', 'SortForm'].each do |form_name|
    const_set(form_name, Form.find("ARSMODELS_#{form_name}")) || missing_forms.push(form_name)
  end
  raise "ERROR: Missing test forms #{missing_forms.collect{|form_name| 'ARSMODELS_' + form_name}.join(', ')}" if missing_forms.length > 0
  
  EnumFieldValue = ArsModels::FieldValues::EnumFieldValue

  BinaryAttachmentFile = File.new(File.join(File.dirname(__FILE__), 'config', 'attachment.bin'))
  TextAttachmentFile = File.new(File.join(File.dirname(__FILE__), 'config', 'attachment.txt'))

  class << self
    # Enable a setup and teardown method that is executed at the beginning
    # and end of each TestSuite.  TestSuite setup and teardown methods are
    # defined as class methods in the Test::Unit::TestCase.  For example:
    #
    #   UsersTest < Test::Unit::TestCase
    #     # This will get executed before any of the tests are run
    #     def self.setup
    #       puts "Starting the test suite..."
    #     end
    #
    #     # This will get executed after all of the tests are run
    #     def self.teardown
    #       puts "Completed test suite."
    #     end
    #
    #     # This will get executed before each of the tests are run
    #     def setup
    #       puts "Starting test..."
    #     end
    #
    #     # This will get executed after each any of the tests are run
    #     def self.teardown
    #       puts "Completed."
    #     end
    #   end
    def suite_with_callbacks
      # Retrieve the suite as it is built normally
      suite = suite_without_callbacks

      # Modify the class methods for the suite instance
      class << suite
        # Add an attribute to store a link to the generating test case
        attr_accessor :test_case

        # Define the alias wrapper method
        def run_with_callbacks(result, &progress_block)
          # Run setup if its defined
          test_case.setup if test_case.respond_to?(:setup)

          begin
            # Run all of the tests
            run_without_callbacks(result, &progress_block)
          ensure
            # Run teardown if it is defined
            test_case.teardown if test_case.respond_to?(:teardown)
          end
        end
        alias_method :run_without_callbacks, :run
        alias_method :run, :run_with_callbacks
      end

      # Set the link to tie the suite to the source TestCase
      suite.test_case = self

      # Return the suite
      suite
    end

    # Wrap the call that builds the test suite so that it calls a setup and teardown method
    alias_method :suite_without_callbacks, :suite
    alias_method :suite, :suite_with_callbacks
  end

  # Exclude this file from test backtraces
  def add_failure(message, all_locations=caller()) # :nodoc:
    @test_passed = false
    backtrace = filter_backtrace(all_locations)
    backtrace = filter_backtrace(backtrace, __FILE__.sub(/\.rb\Z/, ''))
    @_result.add_failure(Test::Unit::Failure.new(name, backtrace, message))
  end
  private :add_failure
end