# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

namespace GEN_SYM do

  task :mocks => [:prepare] do
    Rake.application['gen:mocks:all'].invoke
  end

  # A single `namespace GEN_SYM do` level, not one nested per gen: sub-namespace --
  # see rules_release.rake's own identical reasoning: RakeTaskRegistry resolves a
  # task's semantic tags from its *nearest* enclosing namespace, so nesting one
  # level deeper than necessary here would make gen: tasks resolve to "mocks"/
  # "test_runner" instead of "gen" itself, going unrecognized as test/build tasks.
  desc "Generate mocks for every test without further building or running."
  task 'mocks:all' => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:mocking])
  end

  desc "Generate mocks for single test ([*] test or source file name, with optional path)."
  task 'mocks:*' do
    message = "Oops! '#{GENERATE_MOCKS_TASK_ROOT}*' isn't a real task. " +
              "Use a real test or source file name in place of the wildcard, " +
              "adding as much of its path as needed to identify one file among any same-named tests.\n" +
              "Example: `ceedling #{GENERATE_MOCKS_TASK_ROOT}foo.c` or `ceedling #{GENERATE_MOCKS_TASK_ROOT}unit/foo.c`"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  task :test_runner => [:prepare] do
    Rake.application['gen:test_runner:all'].invoke
  end

  desc "Generate up through test runners for every test without further building or running."
  task 'test_runner:all' => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:test_runner])
  end

  desc "Generate up through test runner for a single test ([*] test or source file name, with optional path)."
  task 'test_runner:*' do
    message = "Oops! '#{GENERATE_TEST_RUNNER_TASK_ROOT}*' isn't a real task. " +
              "Use a real test or source file name in place of the wildcard, " +
              "adding as much of its path as needed to identify one file among any same-named tests.\n" +
              "Example: `ceedling #{GENERATE_TEST_RUNNER_TASK_ROOT}foo.c` or `ceedling #{GENERATE_TEST_RUNNER_TASK_ROOT}unit/foo.c`"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

end
