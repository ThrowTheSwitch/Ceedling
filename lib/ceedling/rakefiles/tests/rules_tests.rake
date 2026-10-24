# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

namespace TEST_SYM do
  # Use rules to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)
  rule(/^#{TEST_TASK_ROOT}\S+$/ => [ # Test task names by regex
      proc do |task_name|
        # Any directory typed ahead of the name (e.g. `test:unit/test_foo.c`) is kept, since it
        # tells one test from a same-named test elsewhere. See TestTaskName.
        test = TestTaskName.test_name( task_name, root: TEST_TASK_ROOT )

        # Provide the filepath for the target test task back to the Rake task
        @ceedling[:file_finder].find_test_file_from_name( test )
      end
  ]) do |test|
    # Do essential Rake-based set up
    @ceedling[:rake_wrapper][:prepare].invoke

    # Execute the test task
    @ceedling[:test_invoker].setup_and_invoke(tests: [test.source], options: [])
  end
end
