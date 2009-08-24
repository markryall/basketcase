require File.dirname(__FILE__) + '/spec_helper'

describe 'Autosync' do
  
  it 'should be able to handle lots of files that need to be added' do 
    
    ENV['PATH'] = "#{File.expand_path(File.dirname(__FILE__))}:#{ENV['PATH']}"
    
    logfile = File.dirname(__FILE__)+'/ct.log'
    
    File.delete(logfile) if File.exists?(logfile) 
        
    File.open(File.dirname(__FILE__)+'/ct.output', 'w') do |io|
      io.puts <<EOF
deleteddir1@@\main\2 [loaded but missing]                Rule: \main\LATEST
deletedfile1.txt@@\main\1 [loaded but missing]           Rule: \main\LATEST
lost+found@@\main\0                                      Rule: \main\LATEST
lsrecurse
newdir1
newfile1.txt
newfile2.txt
updateddir1@@\main\2                                     Rule: \main\LATEST
updatedfiled1.txt@@\main\1 [hijacked]                    Rule: \main\LATEST
.\deleteddir1\deletedfile1.txt@@\main\1 [loaded but missing]             Rule: \main\LATEST
.\newdir1\newfile1.txt
.\updateddir1\deletedfile1.txt@@\main\1 [loaded but missing]             Rule: \main\LATEST
.\updateddir1\newfile1.txt
.\updateddir1\updatedfiled1.txt@@\main\1 [hijacked]      Rule: \main\LATEST
EOF
      io.puts '++++'
      io.puts <<EOF
.@@\main\12                                              Rule: \main\LATEST
EOF
      io.puts '++++'
      io.puts <<EOF
cleartool: Error: Can't modify directory "." because it is not checked out.
cleartool: Error: Can't modify directory "." because it is not checked out.
cleartool: Error: Can't modify directory "." because it is not checked out.
EOF
    end
    
    Basketcase.new.do('auto-sync','-n')
  end
end
