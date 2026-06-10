directory(VALGRIND_BUILD_OUTPUT_PATH)
directory(VALGRIND_ARTIFACTS_PATH)

CLEAN.include(File.join(VALGRIND_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(VALGRIND_ARTIFACTS_PATH, '*'))

CLOBBER.include(File.join(VALGRIND_BUILD_PATH, '**/*'))

task directories: [VALGRIND_BUILD_OUTPUT_PATH, VALGRIND_ARTIFACTS_PATH]

namespace VALGRIND_SYM do

  desc 'Run Valgrind for all tests'
  task all: [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, options:{:build_only => true}.merge(TOOL_COLLECTION_TEST_TASKS))
    COLLECTION_ALL_TESTS.each do |test|
      test_name  = File.basename(test, '.*')
      build_path = File.join(@ceedling[:configurator].project_build_root, TEST_SYM.to_s, 'out', test_name)
      executable = @ceedling[:file_path_utils].form_test_executable_filepath(build_path, test)
      log_path   = File.join(VALGRIND_ARTIFACTS_PATH, "#{test_name}.log")
      command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, ["--log-file=#{log_path}"], executable)
      @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
      @ceedling[:tool_executor].exec(command)
    end
  end

  desc 'Run Valgrind for a single test or executable ([*] real test or source file name, no path).'
  task :* do
    message = "\nOops! '#{VALGRIND_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: ceedling #{VALGRIND_ROOT_NAME}:foo.c\n\n"

    @ceedling[:loginator].log(message, Verbosity::ERRORS)
  end

  # use a rule to increase efficiency for large projects
  # valgrind test tasks by regex
  rule(/^#{VALGRIND_TASK_ROOT}\S+$/ => [
         proc do |task_name|
           test = task_name.sub(/#{VALGRIND_TASK_ROOT}/, '')
           test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
           @ceedling[:file_finder].find_test_file_from_filepath(test)
         end
       ]) do |test|
    @ceedling[:rake_wrapper][:prepare].invoke
    @ceedling[:test_invoker].setup_and_invoke(tests:[test.source], options:{:build_only => true}.merge(TOOL_COLLECTION_TEST_TASKS))
    test_name  = File.basename(test.source, '.*')
    build_path = File.join(@ceedling[:configurator].project_build_root, TEST_SYM.to_s, 'out', test_name)
    executable = @ceedling[:file_path_utils].form_test_executable_filepath(build_path, test.source)
    log_path   = File.join(VALGRIND_ARTIFACTS_PATH, "#{test_name}.log")
    command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, ["--log-file=#{log_path}"], executable)
    @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
    @ceedling[:tool_executor].exec(command)
  end
end
