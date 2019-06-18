require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

class FormUnitTest < Test::Unit::TestCase
  # TODO: Test - FormUnitTest
  
  def test_field_for
    message_type_field_xml  = '<field datatype="ENUM" entrymode="OPTIONAL" id="536870913" label="Message Type Label" name="Message Type">'
    message_type_field_xml += '<option id="0" label="Note" name="Note"/>'
    message_type_field_xml += '<option id="1" label="Warning" name="Warning"/>'
    message_type_field_xml += '<option id="2" label="Error" name="Error"/>'
    message_type_field_xml += '<option id="3" label="Do Not Delete" name="Do Not Delete"/>'
    message_type_field_xml += '</field>'

    assert_equal nil, MessageForm.field_for(0)
    assert_equal nil, MessageForm.field_for(nil)
    assert_equal message_type_field_xml, MessageForm.field_for(536870913).to_xml
    assert_equal message_type_field_xml, MessageForm.field_for('Message Type').to_xml
    assert_equal message_type_field_xml, MessageForm.field_for(:'Message Type Label').to_xml

    assert_equal nil, MessageForm[0]
    assert_equal nil, MessageForm[nil]
    assert_equal message_type_field_xml, MessageForm[536870913].to_xml
    assert_equal message_type_field_xml, MessageForm['Message Type'].to_xml
    assert_equal message_type_field_xml, MessageForm[:'Message Type Label'].to_xml
  end

  def test_field_id_for
    assert_equal 536870913, MessageForm.field_id_for(MessageForm[536870913])
    assert_equal 536870913, MessageForm.field_id_for(536870913)
    assert_equal 536870913, MessageForm.field_id_for('Message Type')
    assert_equal 536870913, MessageForm.field_id_for(:'Message Type Label')

    assert_equal nil, MessageForm.field_id_for(nil)
    assert_equal nil, MessageForm.field_id_for(0)
    assert_equal nil, MessageForm.field_id_for('')
    assert_equal nil, MessageForm.field_id_for(' '.to_sym)
  end

  def test_indexes
    # Should return array of field arrays
    flunk
  end

  def test_new_by_build
    flunk
  end

  def test_new_by_generate
    flunk
  end

  def test_instantiation
#    assert_equal nil, Form.find('KLINK_TempForm')
#    form = Form.new(
#      'KLINK_TempForm',
#      :fields => [
#        {:id => 8, :default_value => 'N/A', :datatype => 'CHAR', :label => 'Short Description Label'},
#        {:name => 'Name', :label => 'Name Label', :datatype => 'CHAR', :required => true}
#      ],
#      :indexes => [[7],['Status', :'Short Description Label']],
#      :permissions => {'Public' => 'HIDDEN'},
#      :sort_fields => [7, :'Short Description Label', 'Request ID']
#    )
#
#    assert_equal 2, form.indexes.length
#    assert_equal [7], form.indexes[0].collect{|field| field.id}
#    assert_equal [7,8], form.indexes[1].collect{|field| field.id}
#
#    assert_equal [7,8,1], form.sort_fields.collect{|field| field.id}
#
#    form.create!
#
#    assert_equal 'KLINK_TempForm', form.name
#
#    assert_equal 10, form.fields.length
#    name_field = form['Name']
#    assert_equal 'CHAR', name_field.datatype
#    assert_equal nil, name_field.default_value
#    assert_equal 'REQUIRED', name_field.entrymode
#    assert_not_nil name_field.id
#    assert_equal 'Name Label', name_field.label
#    assert_equal 'Name', name_field.name
#
#    assert_equal 2, form.indexes.length
#    assert_equal [7], form.indexes[0].collect{|field| field.id}
#    assert_equal [7,8], form.indexes[1].collect{|field| field.id}
#
#    assert_equal({'Public' => 'HIDDEN'}, form.permissions)
#
#    assert_equal [7,8,1], form.sort_fields.collect{|field| field.id}
#
#    form.delete!

    flunk
  end

  def test_save
    # Should update if existing, create otherwise

    # Form.save()
    # form.save

    flunk
  end

  def test_save!
    # Should update if existing, create otherwise

    # Form.save!()
    # form.save!

    flunk
  end
end