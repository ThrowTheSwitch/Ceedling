# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# A single `namespace GEN_SYM do` level, not one nested per gen: sub-namespace --
# each rule's own pattern already fully qualifies its required "gen:mocks:"/
# "gen:test_runner:" prefix (Rake matches a rule's regex against the literal
# invoked task name regardless of how deeply its `rule()` call is textually
# nested, so an inner `namespace :mocks do` here would be purely decorative),
# and RakeTaskRegistry's marker scan resolves a task's semantic tags from its
# *nearest* enclosing namespace -- nesting one level deeper than necessary
# would make it resolve "mocks"/"test_runner" rather than "gen" itself. See
# rules_release.rake for the identical reasoning applied to release: rules.
namespace GEN_SYM do

  # Use a rule to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)
  rule(/^#{GENERATE_MOCKS_TASK_ROOT}\S+$/ => [ # Task names by regex
      proc do |task_name|
        # Any directory typed ahead of the name (e.g. `gen:mocks:unit/foo.c`) is kept, since it
        # tells one test from a same-named test elsewhere. See TestTaskName.
        test = TestTaskName.test_name( task_name, root: GENERATE_MOCKS_TASK_ROOT )

        # Provide the filepath for the target test task back to the Rake task
        @ceedling[:file_finder].find_test_file_from_name( test )
      end
  ]) do |test|
    # Do essential Rake-based set up
    @ceedling[:rake_wrapper][:prepare].invoke

    # Generate just this one test's mocks
    @ceedling[:test_invoker].setup_and_invoke(tests: [test.source], options: [:mocking])
  end

  # Use a rule to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)
  rule(/^#{GENERATE_TEST_RUNNER_TASK_ROOT}\S+$/ => [ # Task names by regex
      proc do |task_name|
        test = TestTaskName.test_name( task_name, root: GENERATE_TEST_RUNNER_TASK_ROOT )

        @ceedling[:file_finder].find_test_file_from_name( test )
      end
  ]) do |test|
    # Do essential Rake-based set up
    @ceedling[:rake_wrapper][:prepare].invoke

    # Generate just this one test's mocks and runner
    @ceedling[:test_invoker].setup_and_invoke(tests: [test.source], options: [:test_runner])
  end

end
