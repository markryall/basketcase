


Given /^a new folder with a new file$/ do
=begin
  Dir.chdir(WORKING_VIEW) do
    create_file(newfile, "spanky new content")
    Basketcase.new.do('add', newfile)
    Basketcase.new.do('ci', '-m', 'adding test file', newfile)
  end
  
  
  Dir.chdir(CONTROL_VIEW) do
    Basketcase.new.do('update', '.')    
    File.exists?(newfile).should == true
  end
=end
end

When /^I run autosynch$/ do
  foo
%{
one
two
three
four
}.should == %{
one
three
two
four
}
end

Then /^I should see the new file and folder committed$/ do
  pending
end