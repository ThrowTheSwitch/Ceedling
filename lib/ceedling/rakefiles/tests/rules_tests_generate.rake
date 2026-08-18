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
        # Yield clean test name => Strip the task string, remove Rake task prefix, and remove any code file extension.
        # Only one configured source extension can actually be present at the end of a given
        # task name, so trying each in turn is safe -- chomp is a no-op for the ones that don't match.
        # Whatever directory the invoker typed ahead of the name (e.g. `gen:mocks:unit/foo.c`)
        # is left exactly as given -- it's not decoration, it's what disambiguates one test
        # from another same-named test elsewhere in the project.
        test = task_name.strip().sub(/^#{GENERATE_MOCKS_TASK_ROOT}/, '')
        EXTENSION_SOURCE.each { |ext| test = test.chomp( ext ) }

        # Normalized to forward slashes so a directory the invoker typed with backslashes
        # (a Windows-style task name run under a POSIX Ruby, e.g. WSL or Cygwin, where
        # File.dirname/basename below don't treat '\' as a separator) still splits correctly.
        test = test.gsub( '\\', '/' )

        # Ensure the test name's own basename begins with the test file prefix, without
        # disturbing any directory the invoker supplied ahead of it.
        dir  = File.dirname( test )
        base = File.basename( test )
        base = PROJECT_TEST_FILE_PREFIX + base if not (base.start_with?( PROJECT_TEST_FILE_PREFIX ))
        test = (dir == '.') ? base : File.join( dir, base )

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
        # See gen:mocks's identical rule above for a full explanation of this resolution.
        test = task_name.strip().sub(/^#{GENERATE_TEST_RUNNER_TASK_ROOT}/, '')
        EXTENSION_SOURCE.each { |ext| test = test.chomp( ext ) }

        test = test.gsub( '\\', '/' )

        dir  = File.dirname( test )
        base = File.basename( test )
        base = PROJECT_TEST_FILE_PREFIX + base if not (base.start_with?( PROJECT_TEST_FILE_PREFIX ))
        test = (dir == '.') ? base : File.join( dir, base )

        @ceedling[:file_finder].find_test_file_from_name( test )
      end
  ]) do |test|
    # Do essential Rake-based set up
    @ceedling[:rake_wrapper][:prepare].invoke

    # Generate just this one test's mocks and runner
    @ceedling[:test_invoker].setup_and_invoke(tests: [test.source], options: [:test_runner])
  end

end
