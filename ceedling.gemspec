# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ceedling/version"

Gem::Specification.new do |s|
  s.name        = "ceedling"
  s.version     = Ceedling::Version::GEM
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mike Karlesky, Mark VanderVoord", "Greg Williams", "Matt Fletcher"]
  s.email       = ["michael@karlesky.net, mvandervoord@gmail.com, williams@atomicembedded.com, fletcher@atomicobject.com"]
  s.homepage    = "http://throwtheswitch.org/"
  s.summary     = %q{Gemified version of the Ceedling C testing / build environment}
  s.description = %q{Gemified version of the Ceedling C testing / build environment}

  s.rubyforge_project = "ceedling"

  s.add_dependency "thor", ">= 0.14.5"
  s.add_dependency "rake", ">= 0.8.7"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
