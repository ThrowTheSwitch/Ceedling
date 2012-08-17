# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
require "ceedling/version"

Gem::Specification.new do |s|
  s.name        = "ceedling"
  s.version     = Ceedling::Version::GEM
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mike Karlesky, Mark VanderVoord", "Greg Williams", "Matt Fletcher"]
  s.email       = ["michael@karlesky.net, mvandervoord@gmail.com, williams@atomicembedded.com, fletcher@atomicobject.com"]
  s.homepage    = "http://throwtheswitch.org/"
  s.summary     = %q{Ceedling is a set of tools for the automation of builds and test running for C}
  s.description = %q{Ceedling provides a set of tools to deploy its guts in a folder or which can be required in a Rakefile}

  s.rubyforge_project = "ceedling"

  s.add_dependency "thor", ">= 0.14.5"
  s.add_dependency "rake", ">= 0.8.7"

  # Files needed from submodules
  s.files         = []
  s.files        += `find vendor/cmock/lib           -name "*.rb"`.split("\n")
  s.files        += `find vendor/cmock/config        -name "*.rb"`.split("\n")
  s.files        += `find vendor/cmock/release       -name "*.info"`.split("\n")
  s.files        += `find vendor/cmock/src           -name "*.[ch]"`.split("\n")
  s.files        += `find vendor/c_exception/lib     -name "*.[ch]"`.split("\n")
  s.files        += `find vendor/c_exception/release -name "*.info"`.split("\n")
  s.files        += `find vendor/unity/auto          -name "*.rb"`.split("\n")
  s.files        += `find vendor/unity/release       -name "*.info"`.split("\n")
  s.files        += `find vendor/unity/src           -name "*.[ch]"`.split("\n")

  s.files        += `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
