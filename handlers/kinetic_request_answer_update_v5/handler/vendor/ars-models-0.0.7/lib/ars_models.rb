# Define the Ars Models package loader file.  This file requires the necessary
# libraries, configures the environment, and then loads each of the Ars Models
# files.  This process exposes the complete Model package to the current Ruby
# environment.
#
# If a specific ArsAPI version is desired, the calling program should manually
# require the arapiXX.jar and arutilXX.jar (ArsModels will not attempt to load
# these pakages if they are already present in the JVM).

# Include the current lib directory in the Ruby load path
$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Require the necessary JRuby libraries
require 'java'

# Try to load an arapi class
begin
  include_class 'com.remedy.arsys.api.ARException'
# If we were not able to load the class
rescue NameError
  # Check for a forced version
  case ENV['ARAPI_VERSION']
    when nil then
      api_path = File.join(File.dirname(__FILE__), "jars/arapi[0-9][0-9].jar")
      latest_api = Dir[api_path].collect{|match|File.basename(match)}.sort.last
      require "jars/#{latest_api}"
      util_path = File.join(File.dirname(__FILE__), "jars/arutil[0-9][0-9].jar")
      latest_util = Dir[util_path].collect{|match|File.basename(match)}.sort.last
      require "jars/#{latest_util}"
    when "6.3" then
      require 'jars/arapi63.jar'
      require 'jars/arutil63.jar'
    when "7.0" then
      require 'jars/arapi70.jar'
      require 'jars/arutil70.jar'
    else raise "Unsupported forced arapi version: #{ENV['FORCE_ARAPI_VERSION'].inspect}"
  end
end

# Require the ArsModels Jar
begin
  include_class 'com.kd.ars.models.datasource.ArsContext'
rescue NameError
  require 'jars/ArsModels_Java_Library.jar'
end

# Declare the ArsModels module and create constant aliases for the Java classes
module ArsModels # :nodoc:
  # Set constants
  ARAPI_VERSION = com.kd.ars.models.utils.ArsVersionUtil.get_api_version.to_s
  VERSION = File.open(File.join(File.dirname(__FILE__),'..','config','VERSION'), "r") {|file| file.gets}

  # Put a load message
  puts "Loaded ArsModels v#{VERSION} using the #{ARAPI_VERSION} ars libraries"

  # Set the simplified aliases for ArAPI classes
  ARException = com.remedy.arsys.api.ARException

  # Set the simplified aliases for ArsModels java classes
  ArsAttachmentFieldValueEntry = com.kd.ars.models.data.ArsAttachmentFieldValueEntry
  ArsContext = com.kd.ars.models.datasource.ArsContext
  ArsDiaryFieldValueEntry = com.kd.ars.models.data.ArsDiaryFieldValueEntry
  ArsEntry = com.kd.ars.models.data.ArsEntry
  ArsEnumField = com.kd.ars.models.structure.ArsEnumField
  ArsEnumFieldOption = com.kd.ars.models.structure.ArsEnumFieldOption
  ArsEnumFieldValueEntry = com.kd.ars.models.data.ArsEnumFieldValueEntry
  ArsField = com.kd.ars.models.structure.ArsField
  ArsFieldValue = com.kd.ars.models.data.ArsFieldValue
  ArsForm = com.kd.ars.models.structure.ArsForm
  ArsMessage = com.kd.ars.models.datasource.ArsMessage
  ArsStatusHistoryFieldValueEntry = com.kd.ars.models.data.ArsStatusHistoryFieldValueEntry
  ArsTextValueEntry = com.kd.ars.models.data.ArsTextValueEntry

  # Force no documentation for meaningless modules
  module ArsModels::Exceptions # :nodoc:
  end
  module ArsModels::Fields # :nodoc:
  end
  module ArsModels::FieldValues # :nodoc:
  end
end

# Load each of the ars wrapper models
Dir[File.join(File.dirname(__FILE__),'ars_models','**','*.rb')].each do |lib|
  require File.expand_path(lib)
end
