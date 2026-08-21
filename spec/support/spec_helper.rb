# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Coverage instrumentation must start before any Ceedling code below is required, or
# Ruby's Coverage module never sees those files' lines at all. Only active when
# CEEDLING_TEST_COVERAGE is exactly 'units' -- this file is also required by the
# system-test suite's own outer rspec process (spec_system_helper.rb requires it too),
# which barely touches lib/ceedling directly itself (the real work happens in each
# system-test child subprocess, instrumented separately by simplecov_boot.rb); a bare
# truthy check here would make that process ALSO claim SimpleCov's "units" resultset
# entry and silently overwrite the real unit-test coverage with its own near-empty
# coverage, since SimpleCov's own multi-process merging replaces rather than
# accumulates same-named entries. Picks up the shared .simplecov config (repo root)
# via SimpleCov's own upward-directory-search autoload. The final HTML report is
# generated once, explicitly, by `rake coverage:report` after both the unit and
# system suites finish, rather than by this process's own exit.
if ENV['CEEDLING_TEST_COVERAGE'] == 'units'
  require 'simplecov'
  SimpleCov.command_name 'units'
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
