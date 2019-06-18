# Define a static driver sample script
require 'ars_models'

# Create the Context instance
admin_context = ArsModels::Context.new(
  :server => '209.98.36.43', :username => 'Demo', :password => ''
)

# Create a contextual form
FormWithAdminContext = ArsModels::Form.context_instance(admin_context)

# Create a specific form with default context
message_form = FormWithAdminContext.find('ARSMODELS_MessageForm')

# Create an entry
entry = message_form.create_entry!(:fields => [7,8])
puts entry.field_values.inspect
  # => {7=>#<ArsModels::FieldValues::EnumFieldValue:0xcb754f @id=0, @label=:New, @value="New">, 8=>"N/A"}

# Update an attribute and explicitely reset the fields you are interested in
entry.update_attributes!({:Status => 1, 'Short Description' => "Brent's mom."}, :fields => [1,7,8])
puts entry.field_value_ids.inspect
  # => [1, 7, 8]

# Delete and entry and specify that you want to retrieve the values for all fields
deleted_entry = entry.delete!(:fields => :all)
puts deleted_entry.field_value_ids.inspect
  # => [1, 2, 3, 4, 5, 6, 7, 8, 15, 536870913]

# Call delete on one existing entry, an entry id, and one deleted entry
entry = message_form.create_entry!(:fields => [1,7,8])
results = message_form.update_entries!(entry, entry.id, deleted_entry, :field_values => {:Status => 3})
puts results.collect{|result| result.is_a?(ArsModels::Entry) ? result.id : result.message}.inspect
  # => ["000000000001417", "000000000001417", "000000000001416"]
puts results.failures.collect{|results_index, exception| exception.to_s}.inspect
  # => ["Entry does not exist in database"]
puts results.successes.collect{|results_index, entry| entry.field_value_ids}.inspect
  # => [[1, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8, 15, 536870913]]