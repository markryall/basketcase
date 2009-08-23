require File.dirname(__FILE__) + '/spec_helper'

describe Basketcase do
  before do
    @io = stub('io')
    @io.stub!(:each_line)
    IO.stub!(:popen).and_return(@io)
    @basketcase = Basketcase.new
    @basketcase.stub!(:exit)
    $stderr.stub!(:puts, :sync)
    $stdout.stub!(:puts)
  end
  
  it 'should sync stderr' do
    $stderr.should_receive(:sync=).with(true)
    @basketcase.do('ls')
  end
  
  it 'should sync stdout' do
    $stdout.should_receive(:sync=).with(true)
    @basketcase.do('ls')
  end
end