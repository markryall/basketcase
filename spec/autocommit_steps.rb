require File.dirname(__FILE__) + '/spec_helper'
load 'cleartool'

describe 'Autocommit' do
    it 'should be able to handle lots of files that need to be added' do
      File.delete(CLEARTOOL_ARGS_LOG) if File.exists?(CLEARTOOL_ARGS_LOG)

      OutputQueue.enqueue(%q{
.@@\main\CHECKEDOUT from \main\15                        Rule: CHECKEDOUT
})

    $stderr.stub!(:puts)
    Basketcase.new.do('auto-commit', '-m', 'a comment')

    File.read(CLEARTOOL_ARGS_LOG).should == <<HERE
ls -recurse .
checkin -cfile basketcase-checkin-comment.tmp .
HERE
    end
end