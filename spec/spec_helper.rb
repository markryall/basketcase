$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
$:.unshift(File.expand_path(File.dirname(__FILE__)))

require 'basketcase'

ENV['PATH'] = "#{File.expand_path(File.dirname(__FILE__))}:#{ENV['PATH']}"