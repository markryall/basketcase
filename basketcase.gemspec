# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{basketcase}
  s.version = "1.1.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["mdub", "mark ryall", "duana stanley"]
  s.date = %q{2009-08-30}
  s.description = %q{TODO}
  s.email = %q{mdub@dogbiscuit.org}
  s.executables = ["basketcase", "bc-mirror"]
  s.extra_rdoc_files = [
    "README.txt"
  ]
  s.files = [
    ".gitignore",
     "History.txt",
     "Manifest.txt",
     "README.txt",
     "Rakefile",
     "VERSION",
     "basketcase.gemspec",
     "bin/basketcase",
     "bin/bc-mirror",
     "lib/array_patching.rb",
     "lib/basketcase.rb",
     "spec/auto_sync_spec.rb",
     "spec/basketcase_spec.rb",
     "spec/cleartool",
     "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/markryall/basketcase}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{clearcase for the masses}
  s.test_files = [
    "spec/auto_sync_spec.rb",
     "spec/basketcase_spec.rb",
     "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
