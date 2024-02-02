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

rule(/#{GCOV_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      _, object = (task_name.split('+'))
      @ceedling[:file_finder].find_build_input_file(filepath: object, context: GCOV_SYM)
    end
  ]) do |target|
    test, object = (target.name.split('+'))

    @ceedling[GCOV_SYM].generate_coverage_object_file(test.to_sym, target.source, object)
  end

task directories: [GCOV_BUILD_OUTPUT_PATH, GCOV_RESULTS_PATH, GCOV_DEPENDENCIES_PATH, GCOV_ARTIFACTS_PATH]

namespace GCOV_SYM do

  desc 'Run code coverage for all tests'
  task all: [:directories] do
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS)
  end

  desc 'Run single test w/ coverage ([*] test or source file name, no path).'
  task :* do
    message = "\nOops! '#{GCOV_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: rake #{GCOV_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts(message)
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:directories] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS))
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc 'Run tests whose test path contains [dir] or [dir] substring.'
  task :path, [:dir] => [:directories] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if File.dirname(test).include?(args.dir.tr('\\', '/'))
    end

    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS))
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests including the given path or path component.")
    end
  end

  # Use a rule to increase efficiency for large projects -- gcov test tasks by regex
  rule(/^#{GCOV_TASK_ROOT}\S+$/ => [
         proc do |task_name|
           test = task_name.sub(/#{GCOV_TASK_ROOT}/, '')
           test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
           @ceedling[:file_finder].find_test_from_file_path(test)
         end
       ]) do |test|
    @ceedling[:rake_wrapper][:directories].invoke
    @ceedling[:test_invoker].setup_and_invoke(tests:[test.source], context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS)
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

