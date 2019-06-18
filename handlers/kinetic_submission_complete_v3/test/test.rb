$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Add each of the vendor directories to the Ruby path so each vendor library can be required by name
Dir[File.join(File.dirname(__FILE__), '..', 'handler', 'vendor', '**')].each do |path|
  path = File.join(path, 'lib') if File.directory?(File.join(path, 'lib'))
  $:.unshift(File.expand_path(path))
end

require 'xmlsimple'
require 'ars_models'
require File.join(File.dirname(__FILE__), '..', 'handler', 'init')

# test data
xml_str = <<XML_STR
<root>
  <entry base_id="AG000C298C9351FYSMSg56ELAAPgAA">
    <context>
      <parameter name='server'></parameter>
      <parameter name='username'></parameter>
      <parameter name='password'></parameter>
      <parameter name='tcpport'></parameter>
      <parameter name='rpcport'></parameter>
      <parameter name='auth'></parameter>
    </context>
    <fields>
      <field name='ValidationStatus'>Fulfillment Complete</field>
      <field name='Request_Status'>Closed</field>
    </fields>
  </entry>
  <returns format="xml">
    <variable name="success"></variable>
    <variable name="exception"></variable>
    <variable name="entry"></variable>
  </returns>
</root>
XML_STR

# setup and run the handler
handler = KineticRequestUpdateBaseHandlerV1.new(xml_str)
vars = handler.execute
puts vars