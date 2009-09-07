
require 'pathname'
require File.dirname(__FILE__)+'/spec_helper'
load 'cleartool'

describe  'modify files' do 
  
  before(:all) do
    FileUtils.mkdir_p(WORKING_VIEW)
    FileUtils.mkdir_p(CONTROL_VIEW)
  end
  
  # add a file
  # commit it
  # update the control view
  # verify it's there
  it 'should add a file to clearcase' do 
    newfile = "newfile-" + Time.now.to_i.to_s + ".txt"
  
    Dir.chdir(WORKING_VIEW) do
      create_file(newfile, "spanky new content")
      Basketcase.new.do('add', newfile)
      Basketcase.new.do('ci', '-m', 'adding test file', newfile)
    end
    
    
    Dir.chdir(CONTROL_VIEW) do
      Basketcase.new.do('update', '.')    
      File.exists?(newfile).should == true
    end  
    
    @@created_file = newfile
  end
  
  it 'should update a file in clearcase' do
    
    new_content = 'i will love you as long as this file exists'
    
    Dir.chdir(WORKING_VIEW) do
      
      file = Pathname(@@created_file)
      file.chmod(file.stat.mode | 0600) unless file.writable?
      
      File.open(@@created_file, 'a') { |io| io.puts new_content}
      Basketcase.new.do('co', '-h', @@created_file)
      Basketcase.new.do('ci', '-m', 'updating test file', @@created_file)
    end
    
    Dir.chdir(CONTROL_VIEW) do
      Basketcase.new.do('update', '.')
      
      file_contents = File.read(@@created_file)
      file_contents.include?(new_content)
      
    end  
  
  end
  
  it 'should delete a file from clearcase' do
    
    Dir.chdir(WORKING_VIEW) do
       File.exists?(@@created_file).should == true
       
       Basketcase.new.do('remove', @@created_file)
       Basketcase.new.do('ci', '-m', 'removing test file', @@created_file)
       
     end
     
    Dir.chdir(CONTROL_VIEW) do
      Basketcase.new.do('update', '.')    
      File.exists?(@@created_file).should == false
    end  
    
  end
  

  
  
  def create_file(filename, content)
    
    File.open(filename, 'w') { |out| out.puts content }
      
  end
  
end