# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
require "ceedling/version"
require 'date'

Gem::Specification.new do |s|
  s.name        = "ceedling"
  s.version     = Ceedling::Version::GEM
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mark VanderVoord", "Michael Karlesky", "Greg Williams"]
  s.email       = ["mark@vandervoord.net", "michael@karlesky.net", "barney.williams@gmail.com"]
  s.homepage    = "http://throwtheswitch.org/ceedling"
  s.summary     = "Ceedling is a build automation tool for C unit test suites that packages up Unity, CMock, and Rake-based build management functionality"
  s.description = <<-DESC
Ceedling is a build automation tool that helps you create and run C unit test suites.

Ceedling provides two core functions: [1] It packages up several tools including the C unit test framework Unity, the Ruby-based mock generation tool CMock, and a C exception library CException. [2] It extends Rake with functionality specific to generating, building, and executing C test suites.

Ceedling projects are created with a YAML configuration file. A variety of conventions within the tool simplify generating mocks from C files and assembling suites of unit test functions.
  DESC
  s.licenses    = ['MIT']

  s.metadata = {
    "homepage_uri"      => s.homepage,
    "bug_tracker_uri"   => "https://github.com/ThrowTheSwitch/Ceedling/issues",
    "documentation_uri" => "https://github.com/ThrowTheSwitch/Ceedling/blob/master/docs/CeedlingPacket.md",
    "mailing_list_uri"  => "https://groups.google.com/forum/#!categories/throwtheswitch/ceedling",
    "source_code_uri"   => "https://github.com/ThrowTheSwitch/Ceedling"
  }
  
  s.required_ruby_version = ">= 2.7.0"
  
  s.add_dependency "thor", ">= 0.14"
  s.add_dependency "rake", ">= 12", "< 14"
  s.add_dependency "deep_merge", "~> 1.2"
  s.add_dependency "constructor", "~> 2"

  # Files needed from submodules
  s.files         = []
  s.files        += Dir['vendor/**/docs/**/*.pdf', 'docs/**/*.pdf', 'vendor/**/docs/**/*.md', 'docs/**/*.md']
  s.files        += Dir['vendor/cmock/lib/**/*.rb']
  s.files        += Dir['vendor/cmock/config/**/*.rb']
  s.files        += Dir['vendor/cmock/src/**/*.[ch]']
  s.files        += Dir['vendor/c_exception/lib/**/*.[ch]']
  s.files        += Dir['vendor/unity/auto/**/*.rb']
  s.files        += Dir['vendor/unity/src/**/*.[ch]']

  s.files      += Dir['**/*']
  s.test_files  = Dir['test/**/*', 'spec/**/*', 'features/**/*']
  s.executables = Dir['bin/**/*'].map{|f| File.basename(f)}

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
