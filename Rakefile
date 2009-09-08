require 'rubygems'
require 'spec/rake/spectask'

=begin
require 'hoe'
require './lib/basketcase.rb'
Hoe.new('basketcase', Basketcase::VERSION) do |p|
  p.developer('mdub', 'mdub@dogbiscuit.org')
  p.remote_rdoc_dir = ''
end
=end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "basketcase"
    gemspec.summary = "clearcase for the masses"
    gemspec.description = "basketcase fork"
    gemspec.email = "mdub@dogbiscuit.org"
    gemspec.homepage = "http://github.com/markryall/basketcase"
    gemspec.authors = ["mdub", 'mark ryall', 'duana stanley']
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

desc "Run all examples"
Spec::Rake::SpecTask.new('spec') do |t|

  #t.spec_files = FileList['spec//.rb']

end

