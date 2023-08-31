require 'reportgenerator_reportinator'
require 'gcovr_reportinator'

directory(GCOV_BUILD_OUTPUT_PATH)
directory(GCOV_RESULTS_PATH)
directory(GCOV_ARTIFACTS_PATH)
directory(GCOV_DEPENDENCIES_PATH)

CLEAN.include(File.join(GCOV_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(GCOV_RESULTS_PATH, '*'))
CLEAN.include(File.join(GCOV_ARTIFACTS_PATH, '*'))
CLEAN.include(File.join(GCOV_DEPENDENCIES_PATH, '*'))

CLOBBER.include(File.join(GCOV_BUILD_PATH, '**/*'))

rule(/#{GCOV_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      _, object = (task_name.split('+'))
      @ceedling[:file_finder].find_compilation_input_file(object)
    end
  ]) do |target|
    test, object = (target.name.split('+'))

    @ceedling[GCOV_SYM].generate_coverage_object_file(test.to_sym, target.source, object)
  end

task directories: [GCOV_BUILD_OUTPUT_PATH, GCOV_RESULTS_PATH, GCOV_DEPENDENCIES_PATH, GCOV_ARTIFACTS_PATH]

namespace GCOV_SYM do

  TOOL_COLLECTION_GCOV_TASKS = {
    :test_compiler  => TOOLS_GCOV_COMPILER,
    :test_assembler => TOOLS_TEST_ASSEMBLER,
    :test_linker    => TOOLS_GCOV_LINKER,
    :test_fixture   => TOOLS_GCOV_FIXTURE
  }

  task source_coverage: COLLECTION_ALL_SOURCE.pathmap("#{GCOV_BUILD_OUTPUT_PATH}/%n#{@ceedling[:configurator].extension_object}")

  desc 'Run code coverage for all tests'
  task all: [:test_deps] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS)
    @ceedling[:configurator].restore_config
  end

  desc 'Run single test w/ coverage ([*] real test or source file name, no path).'
  task :* do
    message = "\nOops! '#{GCOV_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: rake #{GCOV_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts(message)
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:test_deps] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS))
      @ceedling[:configurator].restore_config
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc 'Run tests whose test path contains [dir] or [dir] substring.'
  task :path, [:dir] => [:test_deps] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if File.dirname(test).include?(args.dir.tr('\\', '/'))
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS))
      @ceedling[:configurator].restore_config
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests including the given path or path component.")
    end
  end

  desc 'Run code coverage for changed files'
  task delta: [:test_deps] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, context:GCOV_SYM, options:{ force_run: false }.merge(TOOL_COLLECTION_GCOV_TASKS))
    @ceedling[:configurator].restore_config
  end

  # use a rule to increase efficiency for large projects
  # gcov test tasks by regex
  rule(/^#{GCOV_TASK_ROOT}\S+$/ => [
         proc do |task_name|
           test = task_name.sub(/#{GCOV_TASK_ROOT}/, '')
           test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
           @ceedling[:file_finder].find_test_from_file_path(test)
         end
       ]) do |test|
    @ceedling[:rake_wrapper][:test_deps].invoke
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke(tests:[test.source], context:GCOV_SYM, options:TOOL_COLLECTION_GCOV_TASKS)
    @ceedling[:configurator].restore_config
  end
end

if PROJECT_USE_DEEP_DEPENDENCIES
  namespace REFRESH_SYM do
    task GCOV_SYM do
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].refresh_deep_dependencies
      @ceedling[:configurator].restore_config
    end
  end
end

# Report Creation Utilities
UTILITY_NAME_GCOVR = "gcovr"
UTILITY_NAME_REPORT_GENERATOR = "ReportGenerator"
UTILITY_NAMES = [UTILITY_NAME_GCOVR, UTILITY_NAME_REPORT_GENERATOR]

namespace UTILS_SYM do

  desc "Generate gcov code coverage report(s). (Note: Must run a 'ceedling gcov:' task first)."
  task GCOV_SYM do
    # Get the gcov options from project.yml.
    opts = @ceedling[:configurator].project_config_hash

    # Create the artifacts output directory.
    if !File.directory? GCOV_ARTIFACTS_PATH
      FileUtils.mkdir_p GCOV_ARTIFACTS_PATH
    end

    # Remove unsupported reporting utilities.
    if !(opts[:gcov_utilities].nil?)
      opts[:gcov_utilities].reject! { |item| !(UTILITY_NAMES.map(&:upcase).include? item.upcase) }
    end

    # Default to gcovr when no reporting utilities are specified.
    if opts[:gcov_utilities].nil? || opts[:gcov_utilities].empty?
      opts[:gcov_utilities] = [UTILITY_NAME_GCOVR]
    end

    if opts[:gcov_reports].nil?
      opts[:gcov_reports] = []
    end

    gcovr_reportinator = GcovrReportinator.new(@ceedling)
    gcovr_reportinator.support_deprecated_options(opts)

    if gcovr_reportinator.utility_enabled?(opts, UTILITY_NAME_GCOVR)
      gcovr_reportinator.make_reports(opts)
    end

    if gcovr_reportinator.utility_enabled?(opts, UTILITY_NAME_REPORT_GENERATOR)
      reportgenerator_reportinator = ReportGeneratorReportinator.new(@ceedling)
      reportgenerator_reportinator.make_reports(opts)
    end

  end
end
