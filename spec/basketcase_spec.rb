require File.dirname(__FILE__) + '/spec_helper'

describe Basketcase do
  before do
    @io = stub('io')
    @io.stub!(:each_line)
    IO.stub!(:popen).and_return(@io)
    @basketcase = Basketcase.new
    @basketcase.stub!(:exit)
    $stderr.stub!(:puts, :sync)
    $stdout.stub!(:puts, :sync)
  end
  
  it 'should sync stderr' do
    $stderr.should_receive(:sync=).with(true)
    @basketcase.do('ls')
  end
  
  it 'should sync stdout' do
    $stdout.should_receive(:sync=).with(true)
    @basketcase.do('ls')
  end
  
  it 'should determine test mode from command line option --test' do
    @basketcase.do('--test','ls')
    @basketcase.instance_variable_get('@test_mode').should == true
  end
  
  it 'should determine test mode from command line option -t' do
    @basketcase.do('-t','ls')
    @basketcase.instance_variable_get('@test_mode').should == true
  end
  
  it 'should determine debug mode from command line option --test' do
    @basketcase.do('--debug','ls')
    @basketcase.instance_variable_get('@debug_mode').should == true
  end
  
  it 'should determine debug mode from command line option -te' do
    @basketcase.do('-d','ls')
    @basketcase.instance_variable_get('@debug_mode').should == true
  end
end