# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Injected into each system-test child process's RUBYOPT (see SystemContext#with_context)
# so coverage instrumentation starts before that process's own `require`s run -- Ruby's
# Coverage module only sees lines loaded after it starts. RUBYOPT applies to every
# subprocess spawned while coverage mode is on, not just the one build/appcmd call
# actually being measured, so this re-checks its own gate rather than assuming it's
# only ever loaded when wanted.
if ENV['CEEDLING_TEST_COVERAGE_ROOT']
  require 'simplecov'

  # This process's own CWD is a throwaway deployed project directory, not this repo,
  # so the require above's own upward-directory-search for .simplecov walks straight
  # past the real one and finds nothing. Point root back at the real repo and load
  # the shared config explicitly now that root is correct.
  SimpleCov.root(ENV['CEEDLING_TEST_COVERAGE_ROOT'])
  load File.join(ENV['CEEDLING_TEST_COVERAGE_ROOT'], '.simplecov')

  # SimpleCov's resultset stores one entry per command_name, and a new result under
  # an already-used name *replaces* rather than accumulates with the previous one --
  # a shared name across the many sequential child processes a full system-test run
  # spawns would silently keep only the last one's coverage. PID alone isn't enough
  # (a long run can cycle through enough child processes, each itself spawning
  # further subprocesses for compiles/links/etc., to plausibly repeat a PID);
  # PID plus a microsecond timestamp is.
  SimpleCov.command_name "system-#{Process.pid}-#{Time.now.strftime('%Y%m%d%H%M%S%6N')}"
  # Each of potentially hundreds of these child processes across a full system-test
  # run only needs to merge its own coverage into the shared resultset -- the
  # formatted HTML report is generated once, explicitly, by `rake coverage:report`
  # after both suites finish, not redundantly by every child process's own exit.
  SimpleCov.at_exit { SimpleCov.result }
end
