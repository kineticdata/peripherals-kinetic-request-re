require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

class ContextUnitTest < Test::Unit::TestCase
  def test_accessors
    context = Context.new(
      :username => 'Demo',
      :password => '', 
      :server => '127.0.0.1', 
      :port => '0'
    )
    
    assert_equal 'Demo', context.username
    assert_equal '', context.password
    assert_equal '127.0.0.1', context.server
    assert_equal 0, context.port
  end

  def test_initialize
    # TODO: Test - ContextUnitTest#test_initialize
    # Test Build
    # Context.new(:username, :password, :server, :port)

    # Test Generate
    # Context.new(ars_context)
    flunk
  end

  def test_login
    context = Context.new(FIXTURES[:context][:admin_user])
    assert_equal [], context.login

    context = Context.new(FIXTURES[:context][:admin_user])
    context.password = "!#{context.password}"
    exception = assert_raise(ArsModels::Exceptions::ModelException) {context.login}
    assert_equal 2, exception.message_type
    assert_equal 623, exception.message_number
    assert_equal "Authentication failed", exception.message_text
    assert_equal "", exception.appended_text
  end
end