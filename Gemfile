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
gem "rr"
gem "require_all"

# Dev-only: used by DependencyTracker's :full debug tier to render human-readable
# content diffs. Soft dependency at runtime (lib/ceedling/dependencies/dependency_differ.rb
# requires it defensively and degrades gracefully if absent) -- deliberately NOT declared in
# ceedling.gemspec, so it is never a hard requirement for an installed release gem.
gem "diff-lcs", "~> 1.5"

# Dev-only: code coverage for CI's combined unit+system test coverage report.
# require: false since it's only ever loaded when CEEDLING_TEST_COVERAGE is set --
# deliberately NOT declared in ceedling.gemspec, same as diff-lcs above.
#
# SimpleCov 1.x requires Ruby >= 3.2 and is what CI's coverage-instrumented
# leg (Ruby 3.3 -- see ci.yml) actually targets, giving access to modern
# config method names (cover/skip/group) and the simplecov:disable/enable
# directive comments used throughout .simplecov and bin/cli.rb. Every other
# Ruby leg in CI's matrix (3.0, 3.1, ...) never sets CEEDLING_TEST_COVERAGE
# and so never loads this gem at all -- the ~> 0.22 fallback exists purely
# so `bundle install` still resolves cleanly on those older interpreters,
# not because anything in this repo actually runs against it.
if RUBY_VERSION >= '3.2'
  gem "simplecov", "~> 1.1", require: false
else
  gem "simplecov", "~> 0.22", require: false
end

# Dev-only: sampling call-stack profiler for ad hoc performance investigation
# (flame graphs of a real Ceedling build/test run). Not required by any
# runtime code path -- deliberately NOT declared in ceedling.gemspec, same
# as diff-lcs/simplecov above.
gem "stackprof", "~> 0.2", require: false

# Ceedling dependencies
gem "diy", "~> 1.1"
gem "constructor", "~> 2"
gem "thor", "~> 1.3"
gem "deep_merge", "~> 1.2"

# `erb` & `benchmark` have been removed from the default gems in some Ruby versions Ceedling supports.
# These must be declared explicitly for plain `gem install` (non-Bundler) users to successfully span supported Ruby versions.
gem "erb", ">= 2.2"
gem "benchmark", ">= 0.3"

gem "unicode-display_width", "~> 3.1"
gem "parallel", "~> 1.26"
