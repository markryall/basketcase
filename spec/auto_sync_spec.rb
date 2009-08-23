require File.dirname(__FILE__) + '/spec_helper'

describe 'Autosync' do
  
  it 'should be able to handle lots of files that need to be added' do 
    
    File.open(File.dirname(__FILE__)+'/ct.output', 'w') do |io|
      30.times do |i|
        io.puts "file #{i}"
      end

    end
    
    puts `#{File.dirname(__FILE__)}/cleartool`
    Basketcase.new.do('auto-sync')
  end
  
end