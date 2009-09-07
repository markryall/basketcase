$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
$:.unshift(File.expand_path(File.dirname(__FILE__)))

require 'basketcase'

ENV['PATH'] = "#{File.expand_path(File.dirname(__FILE__))}:#{ENV['PATH']}"

ROOT = File.expand_path(File.dirname(__FILE__)+'/..')

WORKING_VIEW = ENV['BC_WORKING_VIEW']
CONTROL_VIEW = ENV['BC_CONTROL_VIEW']

WORKING_VIEW ||= "#{ROOT}/tmp/views/working-view"
CONTROL_VIEW ||= "#{ROOT}/tmp/views/control-view"