require File.dirname(__FILE__) + '/spec_helper'
load 'cleartool'

describe 'Autosync' do
  
  it 'should be able to handle lots of files that need to be added' do 
    
    ENV['PATH'] = "#{File.expand_path(File.dirname(__FILE__))}:#{ENV['PATH']}"
    
    File.delete(CLEARTOOL_ARGS_LOG) if File.exists?(CLEARTOOL_ARGS_LOG) 
    
    OutputQueue.enqueue(%q{
deleteddir1@@\main\2 [loaded but missing]                Rule: \main\LATEST
deletedfile1.txt@@\main\1 [loaded but missing]           Rule: \main\LATEST
lost+found@@\main\0                                      Rule: \main\LATEST
newdir1
newfile1.txt
newfile2.txt
updateddir1@@\main\2                                     Rule: \main\LATEST
updatedfiled1.txt@@\main\1 [hijacked]                    Rule: \main\LATEST
deleteddir1\deletedfile1.txt@@\main\1 [loaded but missing]             Rule: \main\LATEST
newdir1\newfile1.txt
updateddir
1\deletedfile1.txt@@\main\1 [loaded but missing]             Rule: \main\LATEST
updateddir1\newfile1.txt
updateddir1\updatedfiled1.txt@@\main\1 [hijacked]      Rule: \main\LATEST
}, 

%q{
.@@\main\12                                              Rule: \main\LATEST
},

%q{
cleartool: Error: Can't modify directory "." because it is not checked out.
cleartool: Error: Can't modify directory "." because it is not checked out.
cleartool: Error: Can't modify directory "." because it is not checked out.
})
    
    $stderr.stub!(:puts)
    Basketcase.new.do('auto-sync','-n')
    
    File.read(CLEARTOOL_ARGS_LOG).should == <<HERE
ls -recurse .
ls -directory .
checkout -unreserved -ncomment -nquery .
mkelem -ncomment newdir1 newfile1.txt
ls -directory . newdir1
mkelem -ncomment newfile2.txt newdir1/newfile1.txt
ls -directory . updateddir1
mkelem -ncomment updateddir updateddir1/newfile1.txt
ls -directory .
rmname -ncomment deleteddir1 deletedfile1.txt
ls -directory deleteddir1 1
rmname -ncomment deleteddir1/deletedfile1.txt 1/deletedfile1.txt
checkout -unreserved -ncomment -usehijack updatedfiled1.txt updateddir1/updatedfiled1.txt
HERE
    
  end
  

end
