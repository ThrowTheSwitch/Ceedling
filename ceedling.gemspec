# -*- encoding: utf-8 -*-
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
require "version" # lib/version.rb
require 'date'

Gem::Specification.new do |s|
  s.name        = "ceedling"
  s.version     = Ceedling::Version::GEM
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mark VanderVoord", "Michael Karlesky", "Greg Williams"]
  s.email       = ["mark@vandervoord.net", "michael@karlesky.net", "barney.williams@gmail.com"]
  s.homepage    = "https://throwtheswitch.org/ceedling"
  s.summary     = "Ceedling is a build automation tool for C unit tests and releases. It's a member of the ThrowTheSwitch.org family of tools. It's built upon Unity and CMock."
  s.description = <<-DESC
Ceedling is a build automation tool that helps you create and run C unit test suites.

Ceedling provides two core functions: 
  [1] It packages up several tools including the C unit test framework Unity, the mock generation tool CMock, and other features. 
  [2] It simplifies tool configuration for embedded or native C toolchains and automates the running and reporting of tests.

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
  
  s.required_ruby_version = ">= 3.0.0"
  
  s.add_dependency "thor", "~> 1.3"
  s.add_dependency "rake", ">= 12", "< 14"
  s.add_dependency "deep_merge", "~> 1.2"
  s.add_dependency "diy", "~> 1.1"
  s.add_dependency "constructor", "~> 2"
  s.add_dependency "unicode-display_width", "~> 3.1"

  # Files needed from submodules
  s.files         = []
  s.files        += Dir['vendor/**/docs/**/*.pdf', 'docs/**/*.pdf', 'vendor/**/docs/**/*.md', 'docs/**/*.md']
  s.files        += Dir['vendor/cmock/lib/**/*.rb']
  s.files        += Dir['vendor/cmock/config/**/*.rb']
  s.files        += Dir['vendor/cmock/src/**/*.[ch]']
  s.files        += Dir['vendor/c_exception/lib/**/*.[ch]']
  s.files        += Dir['vendor/unity/auto/**/*.rb']
  s.files        += Dir['vendor/unity/src/**/*.[ch]']

  s.files       += Dir['**/*']
  s.test_files   = Dir['test/**/*', 'spec/**/*', 'features/**/*']
  s.executables  = ['ceedling'] # bin/ceedling

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
