# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'reportgenerator_reportinator'
require 'gcovr_reportinator'

directory(GCOV_BUILD_OUTPUT_PATH)
directory(GCOV_RESULTS_PATH)
directory(GCOV_ARTIFACTS_PATH)
directory(GCOV_DEPENDENCIES_PATH)

CLEAN.include(File.join(GCOV_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(GCOV_RESULTS_PATH, '*'))
CLEAN.include(File.join(GCOV_ARTIFACTS_PATH, '**/*'))
CLEAN.include(File.join(GCOV_DEPENDENCIES_PATH, '*'))

CLOBBER.include(File.join(GCOV_BUILD_PATH, '**/*'))

task directories: [GCOV_BUILD_OUTPUT_PATH, GCOV_RESULTS_PATH, GCOV_DEPENDENCIES_PATH, GCOV_ARTIFACTS_PATH]

namespace GCOV_SYM do

  desc 'Run code coverage for all tests'
  task all: [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke( tests:COLLECTION_ALL_TESTS, context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS )
  end

  desc 'Run single test w/ coverage ([*] test or source file name, no path).'
  task :* do
    message = "Oops! '#{GCOV_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: `ceedling #{GCOV_ROOT_NAME}:foo.c`"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke( tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS) )
    else
      @ceedling[:loginator].log("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc 'Run tests whose test path contains [dir] or [dir] substring.'
  task :path, [:dir] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if File.dirname(test).include?(args.dir.tr('\\', '/'))
    end

    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke( tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS) )
    else
      @ceedling[:loginator].log( 'Found no tests including the given path or path component', Verbosity::ERRORS )
    end
  end

  # Use a rule to increase efficiency for large projects
  rule(/^#{GCOV_TASK_ROOT}\S+$/ => [ # gcov test tasks by regex
     proc do |task_name|
        # Yield clean test name => Strip the task string, remove Rake test task prefix, and remove any code file extension
        test = task_name.strip().sub(/^#{GCOV_TASK_ROOT}/, '').chomp( EXTENSION_SOURCE )

        # Ensure the test name begins with a test name prefix
        test = PROJECT_TEST_FILE_PREFIX + test if not (test.start_with?( PROJECT_TEST_FILE_PREFIX ))

        # Provide the filepath for the target test task back to the Rake task
        @ceedling[:file_finder].find_test_file_from_name( test )
     end
   ]) do |test|
    @ceedling[:rake_wrapper][:prepare].invoke
    @ceedling[:test_invoker].setup_and_invoke( tests:[test.source], context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS )
  end
end

# If gcov config enables dedicated report generation task, create the task
if not @ceedling[GCOV_SYM].automatic_reporting_enabled?
namespace GCOV_REPORT_NAMESPACE_SYM do

  desc "Generate reports from coverage results (Note: a #{GCOV_SYM}: task must be executed first)"
  task GCOV_SYM do
    @ceedling[:gcov].generate_coverage_reports()
  end

end
end

