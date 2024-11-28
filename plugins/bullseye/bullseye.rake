# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

directory(BULLSEYE_BUILD_OUTPUT_PATH)
directory(BULLSEYE_RESULTS_PATH)
directory(BULLSEYE_ARTIFACTS_PATH)
directory(BULLSEYE_DEPENDENCIES_PATH)

CLEAN.include(File.join(BULLSEYE_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(BULLSEYE_RESULTS_PATH, '*'))
CLEAN.include(File.join(BULLSEYE_DEPENDENCIES_PATH, '*'))

CLOBBER.include(File.join(BULLSEYE_BUILD_PATH, '**/*'))
PLUGINS_BULLSEYE_LIB_PATH = 'C:\\tools\\BullseyeCoverage\\lib' if not defined?(PLUGINS_BULLSEYE_LIB_PATH)

rule(/#{BULLSEYE_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
       proc do |task_name|
         @ceedling[:file_finder].find_build_input_file(filepath: task_name, context: BULLSEYE_SYM)
       end
     ]) do |object|

  if File.basename(object.source) =~ /^(#{PROJECT_TEST_FILE_PREFIX}|#{CMOCK_MOCK_PREFIX}|#{BULLSEYE_IGNORE_SOURCES.join('|')})/i
    @ceedling[:generator].generate_object_file(
      TOOLS_BULLSEYE_COMPILER,
      OPERATION_COMPILE_SYM,
      BULLSEYE_SYM,
      object.source,
      object.name,
      @ceedling[:file_path_utils].form_test_build_list_filepath(object.name)
    )
  else
    @ceedling[BULLSEYE_SYM].generate_coverage_object_file(object.source, object.name)
  end

end

rule(/#{BULLSEYE_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_EXECUTABLE}$/) do |bin_file|
  lib_args = @ceedling[:test_invoker].convert_libraries_to_arguments()
  lib_paths = @ceedling[:test_invoker].get_library_paths_to_arguments()
  @ceedling[:generator].generate_executable_file(
    TOOLS_BULLSEYE_LINKER,
    BULLSEYE_SYM,
    bin_file.prerequisites,
    bin_file.name,
    @ceedling[:file_path_utils].form_test_build_map_filepath(bin_file.name),
    lib_args,
    lib_paths
  )
end

rule(/#{BULLSEYE_RESULTS_PATH}\/#{'.+\\'+EXTENSION_TESTPASS}$/ => [
       proc do |task_name|
         @ceedling[:file_path_utils].form_test_executable_filepath(task_name)
       end
     ]) do |test_result|
  @ceedling[:generator].generate_test_results(TOOLS_BULLSEYE_FIXTURE, BULLSEYE_SYM, test_result.source, test_result.name)
end

rule(/#{BULLSEYE_DEPENDENCIES_PATH}\/#{'.+\\'+EXTENSION_DEPENDENCIES}$/ => [
       proc do |task_name|
         @ceedling[:file_finder].find_build_input_file(filepath: task_name, context: BULLSEYE_SYM)
       end
     ]) do |dep|
  @ceedling[:generator].generate_dependencies_file(
    TOOLS_TEST_DEPENDENCIES_GENERATOR,
    BULLSEYE_SYM,
    dep.source,
    File.join(BULLSEYE_BUILD_OUTPUT_PATH, File.basename(dep.source).ext(EXTENSION_OBJECT) ),
    dep.name
  )
end

task :directories => [BULLSEYE_BUILD_OUTPUT_PATH, BULLSEYE_RESULTS_PATH, BULLSEYE_DEPENDENCIES_PATH, BULLSEYE_ARTIFACTS_PATH]

namespace BULLSEYE_SYM do

  TOOL_COLLECTION_BULLSEYE_TASKS = {
    :context        => BULLSEYE_SYM,
    :test_compiler  => TOOLS_BULLSEYE_COMPILER,
    :test_assembler => TOOLS_TEST_ASSEMBLER,
    :test_linker    => TOOLS_BULLSEYE_LINKER,
    :test_fixture   => TOOLS_BULLSEYE_FIXTURE
  }

  task source_coverage: COLLECTION_ALL_SOURCE.pathmap("#{BULLSEYE_BUILD_OUTPUT_PATH}/%n#{@ceedling[:configurator].extension_object}")

  desc 'Run code coverage for all tests'
  task all: [:prepare] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[BULLSEYE_SYM].config)
    @ceedling[BULLSEYE_SYM].enableBullseye(true)
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS, TOOL_COLLECTION_BULLSEYE_TASKS)
    @ceedling[:configurator].restore_config
  end

  desc "Run single test w/ coverage ([*] real test or source file name, no path)."
  task :* do
    message = "\nOops! '#{BULLSEYE_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: rake #{BULLSEYE_ROOT_NAME}:foo.c\n\n"

    @ceedling[:loginator].log( message )
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[BULLSEYE_SYM].config)
      @ceedling[BULLSEYE_SYM].enableBullseye(true)
      @ceedling[:test_invoker].setup_and_invoke(matches, { force_run: false }.merge(TOOL_COLLECTION_BULLSEYE_TASKS))
      @ceedling[:configurator].restore_config
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
      @ceedling[:configurator].replace_flattened_config(@ceedling[BULLSEYE_SYM].config)
      @ceedling[BULLSEYE_SYM].enableBullseye(true)
      @ceedling[:test_invoker].setup_and_invoke(matches, { force_run: false }.merge(TOOL_COLLECTION_BULLSEYE_TASKS))
      @ceedling[:configurator].restore_config
    else
      @ceedling[:loginator].log("\nFound no tests including the given path or path component.")
    end
  end

  desc 'Run code coverage for changed files'
  task delta: [:prepare] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[BULLSEYE_SYM].config)
    @ceedling[BULLSEYE_SYM].enableBullseye(true)
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS, {:force_run => false}.merge(TOOL_COLLECTION_BULLSEYE_TASKS))
    @ceedling[:configurator].restore_config
  end

  # Use a rule to increase efficiency for large projects
  rule(/^#{BULLSEYE_TASK_ROOT}\S+$/ => [ # Bullseye test tasks by regex
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
    @ceedling[BULLSEYE_SYM].enableBullseye(true)
    @ceedling[:test_invoker].setup_and_invoke( [test.source], TOOL_COLLECTION_BULLSEYE_TASKS )
  end

end

namespace UTILS_SYM do

  desc "Open Bullseye code coverage browser"
  task BULLSEYE_SYM do
    command = @ceedling[:tool_executor].build_command_line( TOOLS_BULLSEYE_BROWSER, [] )
    @ceedling[:tool_executor].exec( command )
  end

end
