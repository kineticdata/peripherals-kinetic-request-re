# Define the ArsModels::Entry class.

module ArsModels
  # Ruby wrapper class for the java ArsEntry object.  Instances of Entry
  # represent a single Ars record.
  class Entry < BaseWithContext
    # TODO: Enhancement - Add functionality to determine if self is a delted record

    # TODO: Document ArsModels::Entry#ars_entry attribute
    attr_accessor :ars_entry
    # TODO: Document ArsModels::Entry#context attribute
    attr_accessor :context
    # TODO: Document ArsModels::Entry#field_values attribute
    attr_accessor :field_values
    # TODO: Document ArsModels::Entry#form attribute
    attr_accessor :form
    # TODO: Document ArsModels::Entry#id attribute
    attr_accessor :id
    # TODO: Document ArsModels::Entry#messages attribute
    attr_accessor :messages
    # TODO: Document ArsModels::Entry#modified_attributes attribute
    attr_accessor :modified_attributes

    # TODO: Document ArsModels::Entry initializer
    def initialize(*args)
      super(*args)
    end

    ########################################################################
    # STATIC METHODS
    ########################################################################

    # TODO: Document ArsModels::Entry.create!
    def self.create!(options={})
      # FIXME: This should not be save! directly
      save!(options)
    end

    # === Delete Operations
    # Delete operates with two different selection approaches:
    #
    # <b>Delete All:</b>
    # This will attempt to delete all the records matching the passed conditions
    # and return an array including Entry objects for successfully deleted
    # records and Exceptions::ModelException objects for any records that
    # encountered an error when being deleted.
    #
    # <b>Delete By ID:</b>
    # This can either be a specific id ('000000000000001'), a list of ids
    # ('000000000000001', '000000000000005', '000000000000006'), or an array
    # of ids (['000000000000001', '000000000000005', '000000000000006']). If a
    # single id is passed, the single deleted matching record will be returned
    # (or an Exceptions::ModelException will be raised if an error was 
    # encountered).  If multiple ids are passed, an array including Entry
    # objects for successfully deleted records and Exceptions::ModelException
    # objects for any records that encountered an error when being deleted will
    # be returned.
    #
    # === Multiple Deletion Results
    # Anytime delete is called with the :all operation, or passed multiple IDs
    # to delete, additional helper methods are available for the resulting
    # array.  The +successes+ method will return a hash of results index keys 
    # mapped to the corresponding successfuly deleted entry objects, and the
    # +failures+ method will return a hash of results index keys mapped to the
    # corresponding unsucessfuly entry deletion exceptions.
    #
    # === Delete Options
    #
    # ==== Required Delete Options
    # * <tt>:context</tt> - The Context instance that the delete call should be
    #   executed as.
    # * <tt>:form</tt> - The Form instance representing the Ars schema the
    #   delete call is querying.
    #
    # ==== Optional Delete Options
    # * <tt>:conditions</tt> - An ars qualification fragment a format like:
    #   ['? = "NEW"', 7], ['? = "NEW"', :Status], or ['? = "NEW"', 'Status'],
    #   where the first entry is the qualification string substituting question
    #   marks for each of the field identifiers and the remaining array items
    #   are the field identifiers in order of appearence.  As a shortcut, a hash
    #   of field identifiers to values can be passed in.  For example,
    #   {"Status" => "New", "Group Type" => "View"} equates to
    #   ['? = "New" AND ? = "View"', "Status", "Group Type"].  If any of the
    #   values contain a question mark, it should be escaped (IE '\?' or "\\?").
    #   This can be done via @string.gsub(/\?/, '\?').
    # * <tt>:fields</tt> - :all or an array of field identifiers (string for
    #   name, symbol for label, number for id) indicating which field values
    #   should be included in the results.  Set this parameter to an empty array
    #   for more efficient deletes that return only the ID of the record.
    #   Defaults to :all.
    #
    # === Examples
    #   # Preamble
    #   context = Context.new(:username => 'Demo', :password => '', :server => '127.0.0.1', :port => '0')
    #   group_form = Form.find('Group')
    #
    #   # Delete all non-system groups
    #   results = Entry.delete(:all, :context => context, :form => group_form, :conditions => ["? > 7", 'Group ID'])
    #
    #   # Display the results
    #   puts "Successes: "
    #   results.successes.each do {|results_index, entry| puts "  #{entry.id}"}
    #   puts "Failures: "
    #   results.failures.each do {|results_index, exception| puts "  #{exception.to_s}"}
    #
    #   # Delete a single group entry (Administrators) by id
    #   Entry.delete(000000000000001, :context => context, :form => group_form)
    #   # Delete multiple group entries (Administrators, Public) by id
    #   results = Entry.delete(000000000000001, 000000000000006, :context => context, :form => group_form)
    #   results = Entry.delete([000000000000001,000000000000006], :context => context, :form => group_form)
    #
    #   # Display the results
    #   puts "Successes: "
    #   results.successes.each do {|results_index, entry| puts "  #{entry.id}"}
    #   puts "Failures: "
    #   results.failures.each do {|results_index, exception| puts "  #{exception.to_s}"}
    def self.delete!(*args)
      # TODO: Abstraction - Clean up and document the delete logic chain
      # TODO: Feature Completion - Test paged deletions? (ArsModels::Entry.delete)
      # TODO: Feature Completion - include_attachments? (ArsModels::Entry.delete)
      # TODO: Feature Completion - Messages triggered by deletes

      # Pop the last argument if it is an options hash
      options = args.last.is_a?(::Hash) ? args.pop.clone : {}

      # Default the context if this class was created with a context instance
      options[:context] ||= context if context

      # Validate that the options are valid
      validate_options(options,
        :required => [:context, :form],
        :optional => [:conditions, :fields]
      )

      # Build the array of requested field ids
      field_ids = build_field_ids(options.delete(:fields), options[:form])

      # Call the appropriate find method
      if args.first == :all
        # Build the qualification information
        options[:qualification], options[:qualification_field_ids] = build_qualification(options.delete(:conditions), options[:form])

        # Make the JAPI models call to find all of the matching results
        ars_find_results = ArsEntry.findAll(
          options[:context].ars_context,
          options[:form].ars_form,
          options[:qualification],
          options[:qualification_field_ids].to_java(:Long),
          field_ids.nil? ? nil : field_ids.to_java(:Long)
        )

        # Declare the requried result objects
        results, successes, failures = [], {}, {}

        # Collect the results, converting them to Entry or Exception objects
        ars_find_results.collect do |ars_result|
          begin
            # Call the japi delete method
            ars_result.delete(options[:context].ars_context)
            # Build a new Entry from the japi object
            result = new(ars_result, :context => options[:context], :form => options[:form])
            # Add it to the successes hash
            successes[results.length] = result
            # Add it to the results array
            results << result
          rescue StandardError => exception
            # Process the exception
            exception = Exceptions::InternalError.process(exception)
            # Add the exception to the failures hash
            failures[results.length] = exception
            # Add the exception to the results array
            results << exception
          end
        end
        
        # Add the successes method to the results array
        results_metaclass = class << results; self; end
        results_metaclass.instance_eval do
          define_method(:successes) {successes}
          define_method(:failures) {failures}
        end

        # Return the results
        results
      # If this is no an :all, :first, :last, :rand, or :single search
      else
        # Build the list of ids
        ids = args.flatten.collect {|record| record.is_a?(ArsModels::Entry) ? record.id : record}

        # If there were no entries, return an empty array
        if args.length == 0
          raise ArgumentError.new('Missing arguments specifying records to delete.')
        # If there was one entry, try to delete it
        elsif args.length == 1 && !args.first.is_a?(::Array)
          begin
            # Call the japi delete method
            ars_result = ArsEntry.delete(
              options[:context].ars_context,
              options[:form].ars_form,
              ids.first,
              field_ids.nil? ? nil : field_ids.to_java(:'Long')
            )
            # Build a new Entry from the japi object
            result = new(ars_result, :context => options[:context], :form => options[:form])
          rescue StandardError => exception
            # Process the exception
            raise Exceptions::InternalError.process(exception)
          end
        # If multiple entries were deleted
        else
          # Declare the requried result objects
          results, successes, failures = [], {}, {}

          # Collect the results, converting them to Entry or Exception objects
          ids.collect do |id|
            begin
              # Call the japi delete method
              ars_result = ArsEntry.delete(
                options[:context].ars_context,
                options[:form].ars_form,
                id,
                field_ids.nil? ? nil : field_ids.to_java(:'Long')
              )
              # Build a new Entry from the japi object
              result = new(ars_result, :context => options[:context], :form => options[:form])
              # Add it to the successes hash
              successes[results.length] = result
              # Add it to the results array
              results << result
            rescue StandardError => exception
              # Process the exception
              exception = Exceptions::InternalError.process(exception)
              # Add the exception to the failures hash
              failures[results.length] = exception
              # Add the exception to the results array
              results << exception
            end
          end

          # Add the successes method to the results array
          results_metaclass = class << results; self; end
          results_metaclass.instance_eval do
            define_method(:successes) {successes}
            define_method(:failures) {failures}
          end

          # Return the results
          results
        end
      end
    end

    # === Find Operations
    # Find operates with four different retrieval approaches:
    # 
    # <b>Find All:</b>
    # This will return all the records matched by the options used. If no
    # records are found, an empty array is returned.
    #
    # <b>Find By ID:</b>
    # This can either be a specific id ('000000000000001'), a list of ids
    # ('000000000000001', '000000000000005', '000000000000006'), or an array
    # of ids (['000000000000001', '000000000000005', '000000000000006']). If a
    # single id is passed, the single matched record will be returned, or +nil+
    # if it is not found.  If multiple ids are passed, an array of records will
    # be returned.  Entry ids not found will result in a nil object.
    #
    # <b>Find By Position:</b>
    # There are three options for finding an entry by position.
    # * <tt>:first</tt> - Returns the first record matched by the options used.
    #   If no records are matched, +nil+ is returned.
    # * <tt>:last</tt> - Returns the last record matched by the options used.
    #   If no records are matched, +nil+ is returned.
    # * <tt>:rand</tt> - Returns a random record that matches the options used.
    #   If no records are matched, +nil+ is returned.
    #
    # <b>Find Single:</b>
    # This will return a single record matched by the options used.  If a
    # matching record is not found, +nil+ is returned.  If more than one record
    # is found an exception is raised.  Find single is most frequently used to
    # retrieve a record by GUID or other non-id unique identifier.
    #
    # === Find Options
    #
    # ==== Required Find Options
    # * <tt>:context</tt> - The Context instance that the find call should be
    #   executed as.
    # * <tt>:form</tt> - The Form instance representing the Ars schema the find
    #   call is querying.
    #
    # ==== Optional Find Options
    # * <tt>:conditions</tt> - An ars qualification fragment a format like:
    #   ['? = "NEW"', 7], ['? = "NEW"', :Status], or ['? = "NEW"', 'Status'],
    #   where the first entry is the qualification string substituting question
    #   marks for each of the field identifiers and the remaining array items
    #   are the field identifiers in order of appearence.  As a shortcut, a hash
    #   of field identifiers to values can be passed in.  For example,
    #   {"Status" => "New", "Group Type" => "View"} equates to
    #   ['? = "New" AND ? = "View"', "Status", "Group Type"].  If any of the
    #   values contain a question mark, it should be escaped (IE '\?' or "\\?").
    #   This can be done via @string.gsub(/\?/, '\?').
    # * <tt>:fields</tt> - :all or an array of field identifiers (string for
    #   name, symbol for label, number for id) indicating which field values
    #   should be included in the results.  Defaults to :all.
    # * <tt>:limit</tt> - A number representing the maximum number of entries
    #   returned.  This defaults to the max entry list size set for Remedy.
    # * <tt>:order</tt> - An array of field identifiers (string for name, symbol
    #   for label, number for id) indicating the sort order from most to least
    #   significant.  To reverse the sort order for a field, replace the
    #   identifier with a single element hash that contains the field identifier
    #   as the key, and :desc, 'desc', or 'DESC' as the value.  Numerical field
    #   identifiers can be set to reverse sorting by using their negative.
    #   Defaults to the Form's default sort order.
    # * <tt>:page</tt> - Used when finding all or finding by position, +:page+
    #   indicates the page number, indexed starting at 1, to restrict the search
    #   to.
    #
    # === Pagination
    # When the find all operation is used, the resulting array is patched to
    # include pagination meta-data.  The following method calls are available
    # for the resulting array:
    #
    # * <tt>:total_entries</tt> - The total number of matching results.
    # * <tt>:total_pages</tt> - The total number of pages containing matching
    #   results.
    # * <tt>:current_page</tt> - The current page number, indexed starting at 1,
    #   for the results.
    # * <tt>:previous_page</tt> - The previous page number, indexed starting at
    #   1, for the results.  If the current page is also the first, this will
    #   return +nil+.
    # * <tt>:next_page</tt> - The next page number, indexed starting at 1, for
    #   the results.  If the current page is also the last, this will return
    #   +nil+.
    #
    # === Examples
    #   # Preamble
    #   context = Context.new(:username => 'Demo', :password => '', :server => '127.0.0.1', :port => '0')
    #   group_form = Form.find('Group')
    #
    #   # Find all system groups
    #   Entry.find(:all, :context => context, :form => group_form, :conditions => ["? <= 7", 'Group ID'])
    #
    #   # Find single group entry (Administrators) by id
    #   Entry.find(000000000000001, :context => context, :form => group_form)
    #   # Find multiple group entries (Administrators, Public) by id
    #   Entry.find(000000000000001, 000000000000006, :context => context, :form => group_form)
    #   Entry.find([000000000000001,000000000000006], :context => context, :form => group_form)
    #
    #   # Find the first group alphabetically
    #   Entry.find(:first, :context => context, :form => group_form, :order => ['Group Name'])
    #   # Find the most recently created group
    #   Entry.find(:last, :context => context, :form => group_form, :order => ['Create Date'])
    #   # Find a random group
    #   Entry.find(:rand, :context => context, :form => group_form)
    #
    #   # Find single group entry with the provided unique identifier
    #   Entry.find(:single, :context => context, :form => group_form, :conditions => {'Unique Identifier' => "AG0c29df58dc1rCgRQAGMuAAY_zD"})
    def self.find(*args)
      # TODO: Abstraction - Clean up and document the find logic chain
      # TODO: Feature Completion - Test paged deletions? (ArsModels::Entry.find)
      # TODO: Feature Completion - include_attachments? (ArsModels::Entry.find)

      begin
        # Pop the last argument if it is an options hash
        options = args.last.is_a?(::Hash) ? args.pop.clone : {}

        # Default the context if this class was created with a context instance
        options[:context] ||= context if context
        
        # Validate that the options are valid
        validate_options(options,
          :required => [:context, :form],
          :optional => [
            :conditions,
            :field_ids,
            :fields,
            :include_attachments,
            :limit,
            :order,
            :page
          ]
        )

        # Default shared options
        options[:include_attachments] ||= false

        # Build the array of requested field ids
        options[:field_ids] = build_field_ids(options.delete(:fields), options[:form])

        # Call the appropriate find method
        if [:all, :first, :last, :rand, :single].include?(args.first)
          # Default order
          options[:order] = build_field_ids(options.delete(:order), options[:form]) || options[:form].sort_field_ids

          # Build the qualification information
          options[:qualification], options[:qualification_field_ids] = build_qualification(options.delete(:conditions), options[:form])

          # Call the corresponding find
          case args.first
          when :all then
            # Validate the options
            validate_options(options,
              :required => [
                :context, :form, :field_ids, :include_attachments, :qualification, :qualification_field_ids
              ],
              :optional => [:limit, :order, :page]
            )

            # Compute the chunk index (which is indexed by 0, where :page is indexed by 1)
            chunk_index = options[:page] ? (options[:page] - 1) : 0

            # Get the JAPI results
            find_result = ArsEntry.findAllWithCount(
              options[:context].ars_context,
              options[:form].ars_form,
              options[:qualification],
              options[:qualification_field_ids].to_java('Long'),
              options[:field_ids].nil? ? nil : options[:field_ids].to_java('Long'),
              options[:order].to_java('Long'),
              options[:limit],
              chunk_index,
              options[:include_attachments]
            )

            # Parse the results to get the entries and the count
            ars_entries = find_result[0]
            count = find_result[1]

            # Convert the JAPI entries into ArsModels entries
            result = ars_entries.collect do |ars_entry|
              new(ars_entry, :context => options[:context], :form => options[:form])
            end

            # TODO: Abstraction - Convert this to an include / extend module call so that the results array can be checked via is_a?(ArsModels::Pagination)
            # Add the pagination helper methods
            result_metaclass = class << result; self; end
            result_metaclass.instance_eval do
              define_method(:total_entries) {count}
              define_method(:total_pages)   {options[:limit] == 0 ? 1 : (count.to_f / options[:limit]).ceil}
              define_method(:current_page)  {chunk_index}
              define_method(:previous_page) {chunk_index == 0 ? nil : chunk_index}
              define_method(:next_page)     {chunk_index+1 == total_pages ? nil : chunk_index+2}
            end

            # Return the result set
            result
          when :first, :last then
            # TODO: Feature Completion - Implement first/last for paging (ArsModels::Entry.find)

            # Validate the options
            validate_options(options,
              :required => [:context, :form],
              :optional => [:field_ids, :include_attachments, :order, :qualification, :qualification_field_ids]
            )

            # Reverse the order if looking for the last
            options[:order].collect! {|id| -id} if args.first == :last

            # Make the JAPI models call
            entries = ArsEntry.find_all(
              options[:context].ars_context,
              options[:form].ars_form,
              options[:qualification],
              options[:qualification_field_ids].to_java('Long'),
              options[:field_ids].nil? ? nil : options[:field_ids].to_java('Long'),
              options[:order].to_java('Long'),
              1 # Set the limit to 1
            ).to_a

            # Generate the result
            case entries.length
              when 0 then nil
              when 1 then new(entries.first, :context => options[:context], :form => options[:form])
              else raise 'Multiple entries returned for find by position call.'
            end
          when :rand then
            # TODO: Feature Completion - ArsModels::Entry.find(:rand)
            raise 'Not Implemented'
          when :single then
            # Validate the options
            validate_options(options,
              :required => [:context, :form],
              :optional => [
                :field_ids, :include_attachments, :order, :qualification, :qualification_field_ids
              ]
            )

            # Get the JAPI results
            find_results = ArsEntry.find_all(
              options[:context].ars_context,
              options[:form].ars_form,
              options[:qualification],
              options[:qualification_field_ids].to_java('Long'),
              options[:field_ids].nil? ? nil : options[:field_ids].to_java('Long')
            )

            # Generate the result
            case find_results.length
              when 0 then nil
              when 1 then new(find_results[0], :context => options[:context], :form => options[:form])
              else raise "More than one result found by 'single' search"
            end
          end
        # If this is no an :all, :first, :last, :rand, or :single search
        else
          # Validate the options
          validate_options(options,
            :required => [
              :context,
              :form,
              :field_ids,
              :include_attachments
            ]
          )

          # Convert the list of arguments to an array of Java Strings
          ids = args.to_java(:string)

          # Get the JAPI results
          find_results = ArsEntry.find_all(
            options[:context].ars_context,
            options[:form].ars_form,
            ids,
            options[:field_ids].nil? ? nil : options[:field_ids].to_java('Long')
          )

          # Convert the JAPI entries into ArsModels entries
          results = find_results.collect do |ars_entry|
            ars_entry ? new(ars_entry, :context => options[:context], :form => options[:form]) : nil
          end

          # If there was only one entry requested, return the single result,
          # otherwise return the result array
          ids.length == 1 && find_results.length == 1 ? results.first : results
        end
      rescue NativeException => exception
        raise Exceptions::ModelException.new(exception.cause)
      end
    end
    
    # TODO: Document ArsModels::Entry.update!
    def self.update!(*args)
      # FIXME: This should probably not be save! directly
      # TODO: Enhancement - Implement update!(:single)
      save!(*args)
    end

    ########################################################################
    # INSTANCE METHODS
    ########################################################################

    # TODO: Document ArsModels::Entry#get_field_value
    def get_field_value(attribute)
      raise 'Unable to process field value without form definition' unless form
      field = form.field_for(attribute)
      field_id = field.id
      raise "Unable to retrieve field id for key '#{attribute.inspect}' (#{attribute.class.name})." unless field_id
      begin
        value = @ars_entry.get_field_value(field_id)
      rescue StandardError => error
        raise Exceptions::InternalError.process(error)
      end
      FieldValue.to_ruby(value, :field_id => field_id, :form => form, :entry => self) if value
    end
    alias_method :'[]', :get_field_value

    # TODO: Document ArsModels::Entry#set_field_value
    def set_field_value(attribute, value)
      raise 'Unable to process field value without form definition' unless form
      field = form.field_for(attribute)
      raise "Unable to retrieve field id for key '#{attribute.inspect}' (#{attribute.class.name})." unless field.id
      new_value = FieldValue.to_java(field, value, @ars_entry.get_field_value(field.id))
      @ars_entry.set_field_value(field.id, new_value)
      @modified_attributes.nil? ? @modified_attributes = {field.id => value} : @modified_attributes[field.id] = value
      self
    end
    alias_method :'[]=', :set_field_value

    # TODO: Document ArsModels::Form#delete!
    def delete!(options={})
      # Check for bad options
      validate_options(options, :optional => [:context, :fields])

      # Define the default options
      default_options = {}
      default_options[:context] = context if context
      default_options[:form] = form
      default_options[:fields] = field_value_ids

      # Delete this instance
      self.class.delete!(self.id, default_options.merge(options))
    end

    # TODO: Document ArsModels::Form#update_attributes!
    def update_attributes!(attributes, options={})
      # Check for bad options
      validate_options(options, :optional => [:context, :fields])

      # Define the default options
      default_options = {}
      default_options[:context] = context if context
      default_options[:form] = form
      default_options[:fields] = field_value_ids

      # Save the update
      self.class.save!(self, default_options.merge(options).merge(:field_values => attributes))
    end

    # TODO: Document ArsModels::Form#save!
    def save!(options={})
      # Check for bad options
      validate_options(options, :optional => [:context, :field_values, :fields, :field_ids, :form])

      # Raise an exception if the form specified is not the correct form
      raise "Conflicting forms" if (form && options[:form]) && form.name != options[:form].name

      # Define the default options
      default_options = {}
      default_options[:context] = context if context
      default_options[:form] = form
      default_options[:fields] = field_value_ids

      # Delete this instance
      self.class.save!(self, default_options.merge(options))
    end

    # TODO: Document ArsModels::Form#field_value_ids
    def field_value_ids
      @ars_entry.field_value_ids.to_a
    end

    # TODO: Document ArsModels::Form#field_values
    def field_values # :nodoc:
      # Call the java get method
      @ars_entry.get_field_values.inject({}) do |field_values, ars_field_value|
        field_values[ars_field_value.get_field_id] = FieldValue.to_ruby(
          ars_field_value, :form => form, :field_id => ars_field_value.get_field_id
        )
        field_values
      end
    end

    # TODO: Document ArsModels::Form#field_values=
    def field_values=(attributes) # :nodoc:
      raise 'Unable to process field value without form definition' unless form
      ars_field_values = attributes.collect do |identifier, value|
        field = form.field_for(identifier)
        attributes[field.id] = attributes.delete(identifier)
        @modified_values[identifier] = value
        FieldValue.to_java(field, value)
      end
      @ars_entry.set_field_values(ars_field_values.to_java(:'com.kd.ars.models.data.FieldValue'))
      @modified_attributes = attributes
    end
    
    # TODO: Document ArsModels::Form#to_xml
    def to_xml
      # Call the java method
      @ars_entry.to_xml_string
    end

    ########################################################################
    # ATTRIBUTES
    ########################################################################

    def id # :nodoc:
      # Call the java get method
      @ars_entry.get_id
    end

    def id=(value) # :nodoc:
      # Call the java set method
      @ars_entry.set_id(value.to_s)
    end

    def messages # :nodoc:
      # Call the java get method
      @ars_entry.get_messages.collect {|ars_message| ArsModels::Message.new(ars_message)}
    end

    ########################################################################
    # PRIVATE METHODS
    ########################################################################

  private
    def self.save!(*args)
      # TODO: Abstraction - Clean up and document the save logic chain

      # Pop the last argument if it is an options hash
      options = args.last.is_a?(::Hash) ? args.pop.clone : {}

      # Flatten the arguments so that multiple lists of entries are comined into a single array
      args.flatten!

      # Default the context if this class was created with a context instance
      options[:context] ||= context if context

      # Validate the argument options
      validate_options(options, :required => [:context, :form], :optional => [:conditions, :field_values, :fields, :field_ids])

      # Build up the list of field_ids if a list of filds was passed
      options[:field_ids] = build_field_ids(options[:fields], options[:form]) if options[:fields]

      # Default the field_values option to an empty hash
      options[:field_values] ||= {}

      # If no entries were passed as part of the save call, we are creating an entry
      if args.length == 0
        save_new!(options)
      # If a qualification is being passed
      elsif args.first == :all
        save_all!(options)
      # If one or more entries were passed as part of the save call, update them
      elsif args.length == 1
        save_single!(args.first, options)
      # If there were multiple entries passed,
      else
        save_multiple!(args, options)
      end
    end

    def self.save_all!(options={})
      field_values = options.delete(:field_values)
      # TODO: Enhancement - Determine if we can make this more efficient by reducing the attributes retrieved by find
      entries = find(:all, options)
      conditions = options.delete(:conditions)
      results = save_multiple!(entries, options.merge!(:field_values => field_values))
      options.merge!(:conditions => conditions)
      results
    end

    def self.save_multiple!(entries, options)
      # Declare the requried result objects
      results, successes, failures = [], {}, {}

      # Replace any entry ids with the entries themselves
      entries.collect! do |entry|
        # Verify the passed parameter is an entry
        entry.is_a?(ArsModels::Entry) ? entry : find(entry, :context => options[:context], :form => options[:form])
      end

      # For each of the entries passed
      results = entries.each do |entry|
        begin
          # Save the object
          result = entry.save!(options)
          # Add it to the successes hash
          successes[results.length] = result
          # Add it to the results array
          results << result
        rescue StandardError => exception
          # Process the exception
          exception = Exceptions::InternalError.process(exception)
          # Add the exception to the failures hash
          failures[results.length] = exception
          # Add the exception to the results array
          results << exception
        end
      end

      # Add the successes method to the results array
      results_metaclass = class << results; self; end
      results_metaclass.instance_eval do
        define_method(:successes) {successes}
        define_method(:failures) {failures}
      end

      # Return the results
      results
    end

    def self.save_new!(options={})
      begin
        # Build up the ars_field_values
        ars_field_values = options[:field_values].collect do |id, value|
          FieldValue.to_java(options[:form].field_for(id),value)
        end

        # Create a new ArsEntry object and save it
        ars_entry = ArsEntry.new(
          options[:form].ars_form,
          nil,
          ars_field_values.to_java(:'com.kd.ars.models.data.ArsFieldValue')
        ).save(options[:context].ars_context)

        # Store the messages
        ars_messages = ars_entry.get_messages

        # Retrieve the record (so that we properly obtain default values)
        result = find(
          ars_entry.get_id,
          :context => options[:context],
          :form => options[:form],
          :fields => options[:fields]
        )

        # Add the creation messages to the retrieved record
        result.ars_entry.add_messages(ars_messages)

        # Remove the list of modified attributes
        result.modified_attributes.clear

        # Return the result record
        result
      # If there was an issue creating the record
      rescue StandardError => exception
        # Raise a clean ruby exception
        raise Exceptions::InternalError.process(exception)
      end
    end

    def self.save_single!(entry, options={})
      # Verify the passed parameter is an entry
      entry = entry.is_a?(ArsModels::Entry) ? entry : find(entry, :context => options[:context], :form => options[:form])

      begin
        # Build up the ars_field_values
        ars_field_values = entry.modified_attributes.merge(options[:field_values]).collect do |id, value|
          FieldValue.to_java(options[:form].field_for(id), value)
        end

        # Create a new ArsEntry object and save it
        ars_entry = ArsEntry.new(
          options[:form].ars_form,
          entry.id,
          ars_field_values.to_java(:'com.kd.ars.models.data.ArsFieldValue')
        ).save(options[:context].ars_context)

        # Store the messages
        ars_messages = ars_entry.get_messages

        # Retrieve the record (so that we properly obtain default values)
        result = find(
          ars_entry.get_id,
          :context => options[:context],
          :form => options[:form],
          :fields => options[:fields]
        )

        # Update the ars entry
        entry.ars_entry = result.ars_entry

        # Add the creation messages to the retrieved record
        entry.ars_entry.add_messages(ars_messages)

        # Remove the list of modified attributes
        entry.modified_attributes.clear

        # Return the entry
        entry
      rescue StandardError => exception
        raise Exceptions::InternalError.process(exception)
      end
    end

    def ars_field_values
      field_values.collect {|field_value| field_value.ars_field_value}
    end

    def build(options={})
      # Validate the passed options
      validate_options(options, :required => [:form], :optional => [:context, :field_values])

      # Convert any hash defined fields as fields
      (options[:field_values] || []).collect! do |field_value|
        field_value.is_a?(FieldValue) ? field_value : Field.new(field_value)
      end

      # Set the modified attributes to be nil, signifying that all of them have been changed
      @modified_attributes = {}

      # Store a new JAPI ArsEntry object
      @ars_entry = ArsEntry.new(
        options[:form],
        options[:field_values].to_java('com.kd.ars.models.data.FieldValue')
      )
    end

    def generate(ars_entry, options={})
      # Validate the passed options
      validate_options(options, :required => [], :optional => [:context, :form, :field_values])

      # Raise an error if the provided object is not actually a JAPI entry
      raise 'Invalid com.kd.ars.models.data.ArsEntry.' unless ars_entry.is_a?(ArsEntry)

      # Store the JAPI ArsEntry object
      @ars_entry = ars_entry

      # Set the modified attributes to the empty set
      @modified_attributes = {}

      # If there were options passed in with the ArsEntry object, overwrite the object with those values
      [:context, :form, :field_values].each do |attribute|
        send("#{attribute}=", options[attribute]) if options.has_key?(attribute)
      end
    end

    def self.build_field_ids(field_identifiers, form)
      return nil if field_identifiers.nil? || field_identifiers == :all
      field_identifiers.collect do |field_identifier|
        field_id = form.field_id_for(field_identifier)
        unless field_id
          raise case field_identifier
            when Fixnum then "Unable to retrieve field number #{field_identifier}."
            when Symbol then "Unable to retrieve field :#{field_identifier}."
            else "Unable to retrieve field '#{field_identifier}'."
          end
        end
        field_id
      end
    end

    def self.build_qualification(conditions, form)
      # Initialize the results hash
      results = {}

      # Build up qualification
      case conditions
      # If 
      when ::NilClass then
        results[:qualification], results[:qualification_field_ids] = nil, []
      # If the conditions are being passed in as a qualification fragment
      when ::Array then
        # Initialize the values
        results[:qualification], results[:qualification_field_ids] = "", []
        # If the conditions array has values
        if conditions.length > 0
          # Pull apart the qualification fragment and corresponding field identifiers
          qualification = conditions[0]
          qualification_fields = conditions[1..-1]

          # Initialize the current start index
          start_index = 0
          # For each question mark in the qualification
          while index = qualification.index(/\?/, start_index)
            # If the first character is a question mark, replace it with the field id
            if index == 0
              field_id = form.field_id_for(qualification_fields.shift)
              results[:qualification] << "'#{field_id}'"
              results[:qualification_field_ids] << field_id
            # If the question mark is not escaped
            elsif qualification[index-1,1] != '\\'
              field_id = form.field_id_for(qualification_fields.shift)
              results[:qualification] << "#{qualification[start_index..index-1]}'#{field_id}'"
              results[:qualification_field_ids] << field_id
            # If the question mark was escaped
            else
              results[:qualification] << "#{qualification[start_index..index-2]}?"
            end
            # Increment the start index to occur after the current quotation mark
            start_index = index+1
          end
          results[:qualification] << qualification[start_index..-1]
        end

        results[:qualification_field_ids].uniq!
      # If the conditions are passed in as a shortcut hash
      when ::Hash then
        # Initialize the values
        results[:qualification], results[:qualification_field_ids] = [], []

        # For each condition
        conditions.each do |field_identifier, value|
          # Create a qualification fragment and store the field used
          field_id = form.field_id_for(field_identifier)
          results[:qualification] << "'#{field_id}'=#{value.inspect}"
          results[:qualification_field_ids] << field_id
        end
        # Convert the qualification and field_ids to usible types
        results[:qualification] = results[:qualification].join(' AND ')
        results[:qualification_field_ids].uniq!
      # If the conditions are being passed in as an unrecognized object
      else
        # Raise a bad argument error
        raise ArgumentError.new('Bad :conditions format.')
      end

      # Return the resutls
      return results[:qualification], results[:qualification_field_ids]
    end
  end
end