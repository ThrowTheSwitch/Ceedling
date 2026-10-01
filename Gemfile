# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

source "http://rubygems.org/"

gem "bundler", "~> 2.5"

# Testing tools
gem "rspec", "~> 3.8"
gem "rake", ">= 12", "< 14"
gem "require_all"

# Test-only: spec/system/support/gcov_partials_test_cases.rb parses coverage XML.
# rexml has been removed from the default gems bundled with some Ruby installations
# (same category as benchmark below), so it must be declared explicitly here too.
gem "rexml", ">= 3.2"

# Dev-only: used by DependencyTracker's :full debug tier to render human-readable
# content diffs. Soft dependency at runtime (lib/ceedling/dependencies/dependency_differ.rb
# requires it defensively and degrades gracefully if absent) -- deliberately NOT declared in
# ceedling.gemspec, so it is never a hard requirement for an installed release gem.
gem "diff-lcs", "~> 1.5"

# Dev-only: code coverage for CI's combined unit+system test coverage report.
# require: false since it's only ever loaded when CEEDLING_TEST_COVERAGE is set --
# deliberately NOT declared in ceedling.gemspec, same as diff-lcs above.
#
# The version gate exists to reach a significant SimpleCov feature revision.
# SimpleCov 1.x requires Ruby >= 3.2 and gives access to modern config method names
# (cover/skip/group) and the simplecov:disable/enable directive comments used
# throughout .simplecov and bin/cli.rb. Benefiting from that modernization is only
# possible by gating on Ruby version, hence the branch below.
#
# Coverage reporting is purely a CI mechanism, so it is deliberately confined to the
# one leg that satisfies the version requirement: the `tests-linux` job on Ruby 3.3
# (see ci.yml, where CEEDLING_TEST_COVERAGE is set only when matrix.ruby == '3.3').
# No Windows or macOS leg, and no other Ruby leg, ever sets that variable, so none of
# them load this gem at all. The ~> 0.22 fallback exists purely so `bundle install`
# still resolves cleanly on older interpreters, not because anything in this repo
# actually runs against it.
if RUBY_VERSION >= '3.2'
  gem "simplecov", "~> 1.1", require: false
else
  gem "simplecov", "~> 0.22", require: false
end

# Dev-only: sampling call-stack profiler for ad hoc performance investigation
# (flame graphs of a real Ceedling build/test run). Not required by any
# runtime code path -- deliberately NOT declared in ceedling.gemspec, same
# as diff-lcs/simplecov above. install_if: keeps it out of ordinary `bundle
# install` (CI included) entirely -- only `rake profile:setup` installs it,
# by setting CEEDLING_PROFILING=true first. Gating is necessary, not just
# tidy: its native C extension fails to build on Windows
# (Gem::Ext::BuildError), which broke Windows CI outright when this gem was
# briefly installed unconditionally. Whether stackprof can ever build on
# Windows at all (even via an explicit `rake profile:setup` there) is
# untested and unresolved -- profiling should currently be assumed
# non-Windows-only.
gem "stackprof", "~> 0.2", require: false, install_if: -> { ENV['CEEDLING_PROFILING'] == 'true' }

# Nothing here declares `erb`, and that is deliberate. Ceedling itself no longer uses
# it at all. RSpec does: rspec-core requires `erb` at load time (configuration_options.rb)
# without declaring a dependency on it, and that works only because `erb` is a default
# gem, which is always requirable even under `bundle exec` and even when undeclared.
# Verified a default gem on every Ruby Ceedling supports, through 3.5.
#
# If a future Ruby demotes `erb` to a bundled gem the way it did `benchmark` in 3.5,
# `bundle exec rspec` will fail to load with `cannot load such file -- erb`. The fix is
# a development/test-only declaration here, never a gemspec dependency, since no
# Ceedling runtime code path requires it.

# Ceedling dependencies
gem "diy", "~> 1.1"
gem "constructor", "~> 2"
gem "thor", "~> 1.3"
gem "deep_merge", "~> 1.2"

# `benchmark` has been removed from the default gems in some Ruby versions Ceedling supports.
# It must be declared explicitly for plain `gem install` (non-Bundler) users to successfully span supported Ruby versions.
gem "benchmark", ">= 0.3"

gem "unicode-display_width", "~> 3.1"
gem "parallel", "~> 1.26"
