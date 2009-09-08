
require 'pathname'
require File.dirname(__FILE__)+'/spec_helper'
load 'cleartool'

describe  'modify files' do 
  
  before(:all) do
    FileUtils.mkdir_p(WORKING_VIEW)
    FileUtils.mkdir_p(CONTROL_VIEW)
  end
  
  def create_file_in_clearcase
    
    newfile = "newfile-" + Time.now.to_i.to_s + ".txt"
    Dir.chdir(WORKING_VIEW) do
      File.open(newfile, 'w') { |out| out.puts "spanky new content" }
      Basketcase.new.do('add', newfile)
      Basketcase.new.do('ci', '-m', 'adding test file', newfile)
    end
    
    newfile  
  end
  
  
  it 'should add a file to clearcase' do 
    
    newfile = create_file_in_clearcase
  
    Dir.chdir(CONTROL_VIEW) do
      Basketcase.new.do('update', '.')    
      File.exists?(newfile).should == true
    end  
    
    
  end
  
  it 'should update a file in clearcase' do
    
    testfilename = create_file_in_clearcase
    
    new_content = 'i will love you as long as this file exists'
    
    Dir.chdir(WORKING_VIEW) do
      
      file = Pathname(testfilename)
      file.chmod(file.stat.mode | 0600) unless file.writable?
      File.open(testfilename, 'a') { |io| io.puts new_content}
      
      Basketcase.new.do('co', '-h', testfilename)
      Basketcase.new.do('ci', '-m', 'updating test file', testfilename)
    end
    
    Dir.chdir(CONTROL_VIEW) do
      
      Basketcase.new.do('update', '.')
      
      file_contents = File.read(testfilename)
      file_contents.include?(new_content)
      
    end  
  
  end
  
  it 'should delete a file from clearcase' do
    
    testfilename = create_file_in_clearcase
    
    Dir.chdir(WORKING_VIEW) do
       
       Basketcase.new.do('remove', testfilename)
       Basketcase.new.do('ci', '-m', 'removing test file', testfilename)
       
     end
     
    Dir.chdir(CONTROL_VIEW) do
      Basketcase.new.do('update', '.')    
      File.exists?(testfilename).should == false
    end  
    
  end
  

  
end