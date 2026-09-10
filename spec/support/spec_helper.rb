# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Coverage instrumentation must start before any Ceedling code below is required, or
# Ruby's Coverage module never sees those files' lines at all. Active only when
# CEEDLING_TEST_COVERAGE names this process's own suite exactly -- 'units' or
# 'integration'. This file is ALSO required by the system-test suite's own outer rspec
# process (spec_system_helper.rb requires it too), which barely touches lib/ceedling
# directly itself (the real work happens in each system-test child subprocess,
# instrumented separately by simplecov_boot.rb); a bare truthy check here would make
# that process ALSO claim a resultset entry and silently overwrite real coverage with
# its own near-empty coverage, since SimpleCov's multi-process merging replaces rather
# than accumulates same-named entries. Picks up the shared .simplecov config (repo
# root) via SimpleCov's own upward-directory-search autoload. The HTML reports are
# generated once, explicitly, by `rake coverage:report` after every suite finishes,
# rather than by this process's own exit.
coverage_suite = ENV['CEEDLING_TEST_COVERAGE']
if coverage_suite == 'units' || coverage_suite == 'integration'
  require 'simplecov'
  # .simplecov (already loaded by the require above, via SimpleCov's own
  # autoload) is configuration only -- this explicit call is what actually
  # begins tracking for this process.
  SimpleCov.start
  SimpleCov.command_name coverage_suite

  # Units writes the canonical coverage/.resultset.json. Integration, like the
  # system suite's per-process boots, writes its own raw resultset instead, so
  # `rake coverage:report` can format a standalone integration report and still
  # fold the same data into the combined one -- and so a units run and an
  # integration run in the same coverage/ never merge into one file that both
  # the "units" and "integration" reports would then wrongly draw from.
  SimpleCov.coverage_dir(File.join('coverage', 'raw', 'integration')) if coverage_suite == 'integration'

  SimpleCov.at_exit { SimpleCov.result }
end

require 'require_all'
require 'constructor'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end

here = File.dirname(__FILE__)

$: << File.join(here, '../../bin')
$: << File.join(here, '../../lib')
$: << File.join(here, '../../vendor/cmock/lib')
$: << File.join(here, '../../vendor/unity/auto')
