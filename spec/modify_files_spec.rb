
WD = File.dirname(__FILE__)

require WD + '/spec_helper'
load 'cleartool'

describe  'modify files' do 
  
  # TODO put these somewhere better
  WORKING_VIEW = "#{WD}/../views/working-view"
  CONTROL_VIEW = "#{WD}/../views/control-view"    
  
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

    
  end
  
  def create_file(filename, content)
    
    File.open(filename, 'w') { |out| out.puts content }
      
  end
  
end