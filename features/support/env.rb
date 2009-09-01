
module Foo
  def foo
    puts 'i am foo'
  end
end

World(Foo)

ROOT = File.expand_path(File.dirname(__FILE__) + '/../..')
WORKING_VIEW = "#{ROOT}/tmp/views/working-view"
CONTROL_VIEW = "#{ROOT}/tmp/views/control-view"

Before do
  puts WORKING_VIEW
  FileUtils.mkdir_p(WORKING_VIEW)
  FileUtils.mkdir_p(CONTROL_VIEW)  
end