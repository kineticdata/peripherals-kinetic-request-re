# Define the ArsModels::FieldValue class.

require 'date'
require 'time'

module ArsModels
  # TODO: Expose these facts
  # Date returns a Ruby Date object and takes a Date object or an iso8601 string
  # DateTime returns a Ruby Time object and takes a Date object or an iso8601 string
  # Time returns a Ruby Time object relative to Epoch
  class FieldValue < Base # :nodoc:
    attr_reader :ars_field_value

    def self.to_java(field, value, previous_value=nil)
      raise ArgumentError.new("Invalid FieldValue.to_java argument #{field} (#{field.class.name}).") unless field.is_a?(ArsModels::Field)
      case field.datatype
        when "CHAR" then ArsFieldValue.buildTextValue(field.ars_field, value)
        when "DECIMAL", "INTEGER", "REAL" then ArsFieldValue.buildNumberValue(field.ars_field, value)
        when "CURRENCY" then
          return ArsFieldValue.buildCurrencyValue(field.ars_field) if value.nil?
          value = case value
            when Hash then ArsModels::FieldValues::CurrencyFieldValue.new(value)
            when ArsModels::FieldValues::CurrencyFieldValue then value
            else raise "Unable to convert #{value.class}: #{value.to_s} into a currency value."
          end
          date_string = value.conversion_date || ''
          ArsFieldValue.buildCurrencyValue(field.ars_field, value.value.to_s, value.currency.to_s, date_string)
        when "EMBEDDED_ATTACHMENT" then
          return ArsFieldValue.buildAttachmentValue(field.ars_field) if value.nil?
          value = case value
            when ArsModels::FieldValues::AttachmentFieldValue then
              value
            when File then
              ArsModels::FieldValues::AttachmentFieldValue.new(
                :name => File.basename(value.path),
                :content => open(value.path, "rb") {|io| io.read },
                :size => File.size(value)
              )
            else raise "Unable to convert #{value.class}: #{value.to_s} into an attachment value."
          end
          ArsFieldValue.buildAttachmentValue(field.ars_field, value.name, value.size, value.base64_content)
        when "ENUM" then 
          return ArsFieldValue.buildEnumValue(field.ars_field) if value.nil?
          value = case value
            when ArsModels::FieldValues::EnumFieldValue then 
              option = field.ars_field.get_option_by_id(value.id)
              option.nil? ? (raise "Unable to decode enumeration id for #{value.inspect}") : option.get_id.to_i
            when ::Fixnum then value
              option = field.ars_field.get_option_by_id(value)
              option.nil? ? (raise "Unable to decode enumeration id for #{value.inspect}") : option.get_id.to_i
            when ::String then
              option = field.ars_field.get_option_by_name(value)
              option.nil? ? (raise "Unable to decode enumeration id for #{value.inspect}") : option.get_id.to_i
            when ::Symbol then 
              option = field.ars_field.get_option_by_label(value.to_s)
              option.nil? ? (raise "Unable to decode enumeration id for #{value.inspect}") : option.get_id.to_i
            else raise "Unable to convert #{value.class}: #{value.to_s} into an enumeration value."
          end
          ArsFieldValue.buildEnumValue(field.ars_field, value)
        when "DIARY" then
          value = case value
            when ::String then value
            when ::NilClass then ''
            when ArsModels::FieldValues::DiaryFieldValue then value.text
            else raise "Unable to convert #{value.class}: #{value.to_s} into a diary entry value."
          end
          ArsFieldValue.buildDiaryValue(field.ars_field, value, previous_value)
        when "DATE" then
          value = case value
            when Date, DateTime, Time then value.strftime('%Y-%m-%d')
            else value
          end
          ArsFieldValue.buildDateValue(field.ars_field, value)
        when "TIME" then
          value = value.iso8601 if value.is_a?(Time)
          ArsFieldValue.buildTimeValue(field.ars_field, value)
        when "TIME_OF_DAY" then
          value = value.strftime('%H:%M:%S') if value.is_a?(Time)
          ArsFieldValue.buildTimeOfDayValue(field.ars_field, value)
        else raise "Field type '#{field.datatype}' not implemented."
      end
    end

    def self.to_ruby(ars_field_value, options={})
      case ars_field_value.get_field.get_datatype
        when "CHAR"
          ars_field_value.get_value_entries[0].text if ars_field_value.is_not_null
        when "DECIMAL", "REAL"
          ars_field_value.get_value_entries[0].text.to_f if ars_field_value.is_not_null
        when "DIARY"
          ars_diary_field_value_entries = ars_field_value.get_value_entries.to_a
          text = nil
          if ars_diary_field_value_entries.last &&
             ars_diary_field_value_entries.last.get_user == nil &&
             ars_diary_field_value_entries.last.get_timestamp == nil
            text = ars_diary_field_value_entries.pop.text
          end
          FieldValues::DiaryFieldValue.new(
            ars_diary_field_value_entries.collect do |entry|
              FieldValues::DiaryFieldEntryValue.new(
                :text => entry.get_text,
                :timestamp => entry.get_timestamp ? Time.parse(entry.get_timestamp) : nil,
                :username => entry.get_user
              )
            end,
            text
          )
        when "CURRENCY" then
          if ars_field_value.is_not_null
            ars_currency_field_value_entries = ars_field_value.get_value_entries.to_a
            raise "Invalid currency value" unless ars_currency_field_value_entries.length == 1
            ars_currency_field_value_entry = ars_currency_field_value_entries.last

            functional_currencies = ars_currency_field_value_entry.functional_currency_values.inject({}) do |hash, value|
              hash[value.currency_code.to_sym] = value.value_string unless value.value.nil?
              hash
            end

            FieldValues::CurrencyFieldValue.new(
              :value => ars_currency_field_value_entry.get_value,
              :currency => ars_currency_field_value_entry.get_currency,
              :conversion_date => Time.parse(ars_currency_field_value_entry.get_conversion_date),
              :functional_currencies => functional_currencies
            )
          end
        when "EMBEDDED_ATTACHMENT" then
          if ars_field_value.is_not_null
            ars_attachment_field_value_entries = ars_field_value.get_value_entries.to_a
            raise "Invalid attachment" unless ars_attachment_field_value_entries.length == 1
            ars_attachment_field_value_entry = ars_attachment_field_value_entries.last
            field_value = FieldValues::AttachmentFieldValue.new(
              :name => ars_attachment_field_value_entry.get_attachment_name,
              :size => ars_attachment_field_value_entry.get_attachment_size
            )
            field_value.base64_content = ArsFieldValue.getAttachmentContent(
              options[:form].context.ars_context,
              options[:form].ars_form,
              options[:entry].ars_entry,
              options[:form][options[:field_id]].ars_field
            )
            field_value
          end
        when "ENUM" then
          raise "Missing form option for translating enumeration field." unless options[:form]
          raise "Missing field_id option for translating enumeration field." unless options[:field_id]
          if ars_field_value.is_not_null
            enum_selection = ars_field_value.get_value_entries[0].get_id.to_i
            enum_field = options[:form].field_for(options[:field_id])
            option = enum_field.ars_field.get_option_by_id(enum_selection)
            FieldValues::EnumFieldValue.new(:id => option.get_id.to_i, :value => option.get_name, :label => option.get_label.to_sym)
          end
        when "INTEGER"
          ars_field_value.get_value_entries[0].text.to_i if ars_field_value.is_not_null
        when "STATUS_HISTORY"
          ars_field_value.get_value_entries.collect do |entry|
            {:timestamp => entry.get_timestamp, :user => entry.get_user}
          end
        when "DATE"
          Date.parse(ars_field_value.get_value_entries[0].text) if ars_field_value.is_not_null
        when "TIME"
          Time.parse(ars_field_value.get_value_entries[0].text) if ars_field_value.is_not_null
        when "TIME_OF_DAY"
          Time.parse(ars_field_value.get_value_entries[0].text) if ars_field_value.is_not_null
        else
          raise "Field type '#{ars_field_value.field.get_datatype}' not implemented."
      end
    end
  end
end