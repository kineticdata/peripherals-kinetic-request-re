require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

class FieldUnitTest < Test::Unit::TestCase
  # TODO: Test - Add canonical field tests to FieldUnitTest

  def test_new_from_ars_models
    field = Field.new(
      :datatype => 'CHAR',
      :id => 536870916,
      :label => 'First Name',
      :name => 'FirstName'
    )
    assert_equal 'CHAR', field.datatype
    assert_equal nil, field.default_value
    assert_equal 'OPTIONAL', field.entrymode
    assert_equal 536870916, field.id
    assert_equal 'First Name', field.label
    assert_equal 'FirstName', field.name
    assert_equal '<field datatype="CHAR" entrymode="OPTIONAL" id="536870916" label="First Name" name="FirstName"/>',
      field.to_xml

    field = Field.new(
      :datatype => 'CHAR',
      :default_value => 'N/A',
      :entrymode => 'REQUIRED',
      :id => '536870916',
      :label => 'First Name',
      :name => 'FirstName'
    )
    assert_equal 'CHAR', field.datatype
    assert_equal 'N/A', field.default_value
    assert_equal 'REQUIRED', field.entrymode
    assert_equal 536870916, field.id
    assert_equal 'First Name', field.label
    assert_equal 'FirstName', field.name
    assert_equal '<field datatype="CHAR" default="N/A" entrymode="REQUIRED" id="536870916" label="First Name" name="FirstName"/>',
      field.to_xml

    field = Field.new(
      :label => 'First Name',
      :name => 'FirstName',
      :datatype => 'CHAR'
    )
    assert_equal 'CHAR', field.datatype
    assert_equal nil, field.default_value
    assert_equal 'OPTIONAL', field.entrymode
    assert_equal nil, field.id
    assert_equal 'First Name', field.label
    assert_equal 'FirstName', field.name
    assert_equal '<field datatype="CHAR" entrymode="OPTIONAL" label="First Name" name="FirstName"/>',
      field.to_xml
  end
  
  def test_new_from_japi
    context = ArsModels::Context.new(FIXTURES[:context][:admin_user])
    form = ArsModels::Form.find('KLINK_DefaultForm', :context => context)

    field = form[1]
    assert_equal 'CHAR', field.datatype
    assert_equal nil, field.default_value
    assert_equal 'SYSTEM', field.entrymode
    assert_equal 1, field.id
    assert_equal 'Request ID', field.label
    assert_equal 'Request ID', field.name
    assert_equal '<field datatype="CHAR" entrymode="SYSTEM" id="1" label="Request ID" name="Request ID"/>',
      field.to_xml

    field = Field.new(field.ars_field)
    assert_equal 'CHAR', field.datatype
    assert_equal nil, field.default_value
    assert_equal 'SYSTEM', field.entrymode
    assert_equal 1, field.id
    assert_equal 'Request ID', field.label
    assert_equal 'Request ID', field.name
    assert_equal '<field datatype="CHAR" entrymode="SYSTEM" id="1" label="Request ID" name="Request ID"/>',
      field.to_xml
  end
end