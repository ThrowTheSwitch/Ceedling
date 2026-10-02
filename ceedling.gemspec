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
    "documentation_uri" => "https://docs.throwtheswitch.org/Ceedling/",
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

  # `benchmark` is no longer a default gem as of Ruby 3.5, so it must be declared
  # explicitly for plain `gem install` (non-Bundler) users. The floor is kept loose
  # so Ruby's own built-in copy satisfies it on any version that still bundles one,
  # rather than forcing an unnecessary fetch.
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
  # Dir['**/*'] above sweeps the working tree, so anything a local run leaves behind
  # would otherwise be packaged into a release.
  #
  # System test artifacts are the worst of it. `rake spec:system:debug:*` retains whole
  # deployed projects under specout/, which both bloats the gem and breaks packaging
  # outright, since a retained project nests a vendored Ceedling deep enough to exceed
  # the tar name limit (Gem::Package::TooLongFileName).
  #
  # Build output matters for a second reason. Running the examples or the plugin example
  # projects locally fills their build/ directories with object files and executables,
  # and shipping compiled binaries in a release gem is exactly what trips the security
  # scanners described in docs/SECURITY.md. `build` is matched as a whole path segment
  # on purpose: each vendored submodule ships a `meson.build` file, and a substring test
  # would silently drop all three.
  s.files.reject! do |f|
    f.start_with?('site-web/') ||                        # Hosted/versioned docs site -- not needed offline
    f == 'tools' || f.start_with?('tools/') ||            # Dev tooling the Rakefile above shells out to
    f == 'docs/mkdocs' || f.start_with?('docs/mkdocs/') ||  # Raw docs source -- site-local/ is the built artifact the gem actually serves
    f == 'specout' || f.start_with?('specout/') ||        # Retained system test artifacts and run logs
    f == 'build' || f.start_with?('build/') || f.include?('/build/')  # Local build output
  end

  # Dir['**/*'] cannot see dotfiles, and a few are required for the spec suites that
  # ship with this gem to run at all. Those suites exist to support certification
  # self-testing, driven by separate tooling against the versioned gem, which is also
  # why spec/, Gemfile, and Gemfile.lock are packaged rather than trimmed out.
  #
  # .rspec carries the `-I spec/support` load paths that every spec's
  # `require 'spec_helper'` depends on. Without it rspec cannot load a single spec file,
  # failing with `cannot load such file -- spec_helper`.
  #
  # .simplecov is the shared coverage configuration that both spec/support/spec_helper.rb
  # and spec/support/system/simplecov_boot.rb load by name.
  #
  # The fff plugin ships its own separate spec suite with its own .rspec.
  #
  # Added after the rejections above deliberately. None of these match a rejection
  # pattern, and listing them explicitly keeps git-only dotfiles (.gitignore,
  # .gitattributes, .gitmodules) and build output out.
  s.files += [
    '.rspec',
    '.simplecov',
    'plugins/fff/.rspec',
  ].select { |f| File.exist?( f ) }

  s.test_files = Dir['test/**/*', 'spec/**/*', 'features/**/*']
  s.executables = ['ceedling'] # bin/ceedling

  s.require_paths = ["lib", "vendor/cmock/lib"]
end
