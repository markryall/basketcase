require File.dirname(__FILE__) + '/spec_helper'

describe 'Autosync' do
  
  it 'should be able to handle lots of files that need to be added' do 
    
    ENV['PATH'] = "#{File.expand_path(File.dirname(__FILE__))}:#{ENV['PATH']}"
    
    logfile = File.dirname(__FILE__)+'/ct.log'
    
    File.delete(logfile) if File.exists?(logfile) 
        
    File.open(File.dirname(__FILE__)+'/ct.output', 'w') do |io|
      10.times do |i|
        io.puts "file #{i}"
      end
      io.puts '++++'
      10.times do |i|
        io.puts "directory #{i}"
      end
      io.puts '++++'
      io.puts 'foo'
    end
    
    Basketcase.new.do('auto-sync','-n')
  end
end
