# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
require "ceedling/version"
require 'date'

Gem::Specification.new do |s|
  s.name        = "ceedling"
  s.version     = Ceedling::Version::GEM
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mike Karlesky, Mark VanderVoord", "Greg Williams", "Matt Fletcher"]
  s.email       = ["michael@karlesky.net, mvandervoord@gmail.com, williams@atomicobject.com, fletcher@atomicobject.com"]
  s.homepage    = "http://throwtheswitch.org/"
  s.summary     = %q{Ceedling is a set of tools for the automation of builds and test running for C}
  s.description = %q{Ceedling provides a set of tools to deploy its guts in a folder or which can be required in a Rakefile}
  s.licenses    = ['MIT']

  s.add_dependency "thor", ">= 0.14.5"
  s.add_dependency "rake", ">= 0.8.7"
  s.add_runtime_dependency "constructor", ">= 1.0.4"

  # Files needed from submodules
  s.files         = []
  s.files        += Dir['vendor/**/docs/**/*.pdf', 'docs/**/*.pdf', 'vendor/**/docs/**/*.md', 'docs/**/*.md']
  s.files        += Dir['vendor/cmock/lib/**/*.rb']
  s.files        += Dir['vendor/cmock/config/**/*.rb']
  s.files        += Dir['vendor/cmock/release/**/*.info']
  s.files        += Dir['vendor/cmock/src/**/*.[ch]']
  s.files        += Dir['vendor/c_exception/lib/**/*.[ch]']
  s.files        += Dir['vendor/c_exception/release/**/*.info']
  s.files        += Dir['vendor/unity/auto/**/*.rb']
  s.files        += Dir['vendor/unity/release/**/*.info']
  s.files        += Dir['vendor/unity/src/**/*.[ch]']

  s.files      += Dir['**/*']
  s.test_files  = Dir['test/**/*', 'spec/**/*', 'features/**/*']
  s.executables = Dir['bin/**/*'].map{|f| File.basename(f)}

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
