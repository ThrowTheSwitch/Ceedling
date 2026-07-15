# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

directory(BULLSEYE_BUILD_OUTPUT_PATH)
directory(BULLSEYE_RESULTS_PATH)
directory(BULLSEYE_ARTIFACTS_PATH)
directory(BULLSEYE_DEPENDENCIES_PATH)

CLEAN.include(File.join(BULLSEYE_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(BULLSEYE_RESULTS_PATH, '*'))
CLEAN.include(File.join(BULLSEYE_ARTIFACTS_PATH, '**/*'))
CLEAN.include(File.join(BULLSEYE_DEPENDENCIES_PATH, '*'))
CLEAN.include(BULLSEYE_COVFILE_PATH)

CLOBBER.include(File.join(BULLSEYE_BUILD_PATH, '**/*'))
CLOBBER.include(BULLSEYE_COVFILE_PATH)

task directories: [BULLSEYE_BUILD_OUTPUT_PATH, BULLSEYE_RESULTS_PATH, BULLSEYE_DEPENDENCIES_PATH, BULLSEYE_ARTIFACTS_PATH]

# No object compilation, linking, test execution, or dependency-file Rake rules are
# defined here. Ceedling's core build pipeline already compiles and links every test
# build for any context passed to `setup_and_invoke`; `Bullseye`'s `pre_compile_execute`/
# `pre_link_execute` hooks (see `lib/bullseye.rb`) swap in Bullseye's own tools and
# coverage defines for the `bullseye:` context as that pipeline runs.
namespace BULLSEYE_SYM do

  desc 'Run code coverage for all tests'
  task all: [:prepare] do
    # Run tests with coverage
    @ceedling[:test_invoker].setup_and_invoke( tests:COLLECTION_ALL_TESTS, context:BULLSEYE_SYM, options:TOOL_COLLECTION_BULLSEYE_TASKS )

    # Optionally compile untested sources with coverage for complete source coverage results in the final report.
    # This comes after the tests because it depends on the accrued knowledge of which source files have associated tests.
    @ceedling[:bullseye].process_untested_sources( sources:COLLECTION_ALL_SOURCE )
  end

  desc 'Run single test w/ coverage ([*] test or source file name, no path).'
  task :* do
    message = "Oops! '#{BULLSEYE_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: `ceedling #{BULLSEYE_ROOT_NAME}:foo.c`"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke( tests:matches, context:BULLSEYE_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_BULLSEYE_TASKS) )
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
      @ceedling[:test_invoker].setup_and_invoke( tests:matches, context:BULLSEYE_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_BULLSEYE_TASKS) )
    else
      @ceedling[:loginator].log( 'Found no tests including the given path or path component', Verbosity::ERRORS )
    end
  end

  # Use a rule to increase efficiency for large projects
  rule(/^#{BULLSEYE_TASK_ROOT}\S+$/ => [ # bullseye test tasks by regex
     proc do |task_name|
        # Yield clean test name => Strip the task string, remove Rake test task prefix, and remove any code file extension
        test = task_name.strip().sub(/^#{BULLSEYE_TASK_ROOT}/, '').chomp( EXTENSION_SOURCE )

        # Ensure the test name begins with a test name prefix
        test = PROJECT_TEST_FILE_PREFIX + test if not (test.start_with?( PROJECT_TEST_FILE_PREFIX ))

        # Provide the filepath for the target test task back to the Rake task
        @ceedling[:file_finder].find_test_file_from_name( test )
     end
   ]) do |test|
    @ceedling[:rake_wrapper][:prepare].invoke
    @ceedling[:test_invoker].setup_and_invoke( tests:[test.source], context:BULLSEYE_SYM, options:TOOL_COLLECTION_BULLSEYE_TASKS )
  end

  # Only defined when :untested_sources is ':compile' — lets a user iterate on getting
  # untested-source coverage compilation working without paying for a full bullseye:
  # test suite run each time.
  if @ceedling[BULLSEYE_SYM].untested_sources_compile_enabled?
    desc 'Compile all untested source files with coverage'
    task :untested_sources => [:prepare] do
      # sources_only: true — populate the tested-sources mapping (which sources each test
      # references) without compiling, linking, or executing any test.
      @ceedling[:test_invoker].setup_and_invoke(
        tests: COLLECTION_ALL_TESTS,
        context: BULLSEYE_SYM,
        options: { sources_only: true }
      )
      @ceedling[:bullseye].process_untested_sources( sources: COLLECTION_ALL_SOURCE, guidance: false )
    end
  end

end

# If bullseye config enables dedicated report generation task, create the task
if not @ceedling[BULLSEYE_SYM].automatic_html_reporting_enabled?
namespace BULLSEYE_REPORT_NAMESPACE_SYM do

  desc "Generate HTML coverage report (Note: a #{BULLSEYE_SYM}: task must be executed first)"
  task BULLSEYE_SYM do
    @ceedling[:bullseye].generate_html_report()
  end

end
end

namespace UTILS_SYM do

  desc "Open Bullseye code coverage browser"
  task BULLSEYE_SYM do
    command = @ceedling[:tool_executor].build_command_line( TOOLS_BULLSEYE_BROWSER, [] )
    @ceedling[:tool_executor].exec( command )
  end

end
