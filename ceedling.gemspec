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
  s.summary     = "Ceedling is a build automation tool for C unit tests and releases. It is a member of the ThrowTheSwitch.org family of tools, built upon Unity, CMock, and CException."
  s.description = <<-DESC
Ceedling is a build automation tool for C projects. It is especially adept at building and executing unit test suites — even for tricky embedded systems.

Ceedling provides three core functions:
  [1] It packages up several tools including the C unit test framework Unity, the mock generation tool CMock, and other complementary frameworks and libraries.
  [2] It simplifies configuration for C toolchains.
  [3] It automates the running and reporting of test suites as well as release builds.

Ceedling projects start with a YAML configuration file. A variety of conventions simplify assembling suites of unit test functions and producing release builds.
  DESC
  s.licenses    = ['MIT']

  s.metadata = {
    "homepage_uri"      => s.homepage,
    "bug_tracker_uri"   => "https://github.com/ThrowTheSwitch/Ceedling/issues",
    "documentation_uri" => "https://throwtheswitch.github.io/Ceedling/",
    "mailing_list_uri"  => "https://throwtheswitch.discourse.group",
    "source_code_uri"   => "https://github.com/ThrowTheSwitch/Ceedling",
    "funding_uri"       => "https://github.com/sponsors/ThrowTheSwitch"
  }
  
  s.required_ruby_version = ">= 3.0.0"
  
  # Used for both development and runtime
  s.add_dependency "rake", ">= 12", "< 14"

  s.add_dependency "diy", "~> 1.1"
  s.add_dependency "constructor", "~> 2"
  s.add_dependency "thor", "~> 1.3"
  s.add_dependency "deep_merge", "~> 1.2"

  # `erb` is no longer a default gem on some Ruby versions Ceedling supports;
  # it must be declared explicitly for plain `gem install` (non-Bundler) users.
  # >= 2.2: minimum `erb` version supporting what Ceedling uses. A loose floor lets
  # Ruby's own built-in `erb` satisfy this on any Ruby that still bundles one,
  # avoiding an unnecessary fetch + native-compile of standalone `erb`/`cgi` gems.
  s.add_dependency "erb", ">= 2.2"
  # `benchmark` is no longer part of the default gems with Ruby 3.5
  s.add_dependency "benchmark", ">= 0.3"

  s.add_dependency "unicode-display_width", "~> 3.1"
  s.add_dependency "parallel", "~> 1.26"

  # Files needed from submodules
  s.files         = []
  s.files        += Dir['vendor/**/docs/**/*.pdf', 'docs/**/*.pdf', 'vendor/**/docs/**/*.md', 'docs/**/*.md']
  s.files        += Dir['vendor/cmock/lib/**/*.rb']
  s.files        += Dir['vendor/cmock/config/**/*.rb']
  s.files        += Dir['vendor/cmock/src/**/*.[ch]']
  s.files        += Dir['vendor/c_exception/lib/**/*.[ch]']
  s.files        += Dir['vendor/unity/auto/**/*.rb']
  s.files        += Dir['vendor/unity/src/**/*.[ch]']

  s.files        += Dir['**/*']
  s.files.reject! { |f| f.start_with?('site-web/') }

  s.test_files = Dir['test/**/*', 'spec/**/*', 'features/**/*']
  s.executables = ['ceedling'] # bin/ceedling

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
