require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

class EntryUnitTest < Test::Unit::TestCase
  def test_ars_field_values
    # TODO: Test - EntryUnitTest#test_ars_field_values
    flunk
  end

  def test_build_field_ids
    # TODO: Test - EntryUnitTest#test_build_field_ids
    flunk
  end

  def test_bracket_accessor
    # TODO: Test - EntryUnitTest#test_bracket_accessor
    # Assert entry[1] works when 1 is specified as a field id
    # Assert entry[1] produces a ModelException when the field id is not specified
    flunk
  end

  def test_build_qualification
    # TODO: Test - Update EntryUnitTest#test_build_qualification

    # Retrieve the default form
    form = Form.find('KLINK_DefaultForm')

    # Test unescaped qualifications
    assert_equal "1=1",
      Entry.build_qualification(['1=1'], form)
    assert_equal "'7'='8'",
      Entry.build_qualification(['?=?', 7, 8], form)
    assert_equal "1=1 AND '7'=\"NEW\"",
      Entry.build_qualification(['1=1 AND ?="NEW"', 7], form)
    assert_equal "'7'=\"NEW\" AND '8' = \"N/A\"",
      Entry.build_qualification(['?="NEW" AND ? = "N/A"', 7, 8], form)
    assert_equal "'' Test",
      Entry.build_qualification(['? Test'], form)
    assert_equal "(('7'=\"NEW\") OR ('8'=\"N/A\"))",
      Entry.build_qualification(['((?="NEW") OR (?="N/A"))', 7, 8], form)
    assert_equal "(('7'=\"NEW\") OR ('8'=\"N/A\"))",
      Entry.build_qualification(['((?="NEW") OR (?="N/A"))', 7, 8, 9], form)

    # Test question mark escaping
    assert_equal "\"?\"=\"?\" AND 1=1",
      Entry.build_qualification(['"\\?"="\\?" AND 1=1'], form)
    assert_equal "'7'='8' AND \"?\"=\"?\"",
      Entry.build_qualification(['?=? AND "\\?"="\\?"', 7, 8], form)
    assert_equal "(('7'=\"NEW\") OR \"?\"=\"?\" OR ('8'=\"N/A\"))",
      Entry.build_qualification(['((?="NEW") OR "\\?"="\\?" OR (?="N/A"))', 7, 8], form)
  end

  def test_field_values
    # TODO: Test - EntryUnitTest#test_field_values
    # Retrieved
    
    # Generated
    
    flunk
  end

  def test_save
    # TODO: Test - EntryUnitTest#test_save
    flunk
  end

  def test_to_xml
    # TODO: Test - EntryUnitTest#test_to_xml
    flunk
  end
end