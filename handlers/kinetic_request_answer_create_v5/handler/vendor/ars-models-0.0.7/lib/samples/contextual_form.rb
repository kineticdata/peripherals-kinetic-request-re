# Create a new Context
adminContext = ArsModels::Context.new(:server => '209.98.36.43', :timezone => '-05:00', :username => 'Demo')

# Create a new ArsModeld::Form class with the default context set
Form = ArsModels::Form.context_instance(AdminContext)

# Use the previously created class to find a form without explicitly passing the context
MessageForm = Form.find('KLINK_MessageForm')

# Use the form passthrough methods to make ArsModels::Entry calls without explicitly passing the form.  See the ArsModels::Entry documentation for argument and option parameters
MessageForm.create_entry!(*args)
MessageForm.delete_entries!(*args)
MessageForm.delete_entry!(entry_identifier, options={})
MessageForm.find_entries(*args)
MessageForm.find_entry(entry_identifier, options={})
MessageForm.update_entries!(*args)
MessageForm.update_entry!(entry_identifier, options={})