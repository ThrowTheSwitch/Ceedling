directory(VALGRIND_BUILD_OUTPUT_PATH)

CLEAN.include(File.join(VALGRIND_BUILD_OUTPUT_PATH, '*'))

CLOBBER.include(File.join(VALGRIND_BUILD_PATH, '**/*'))

task directories: [VALGRIND_BUILD_OUTPUT_PATH]

namespace VALGRIND_SYM do
  task source_coverage: COLLECTION_ALL_SOURCE.pathmap("#{VALGRIND_BUILD_OUTPUT_PATH}/%n#{@ceedling[:configurator].extension_object}")

  desc 'Run Valgrind for all tests'
  task all: [:test_deps] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
    COLLECTION_ALL_TESTS.each do |test|
      executable = @ceedling[:file_path_utils].form_test_executable_filepath(test)
      command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
      @ceedling[:streaminator].stdout_puts("\nINFO: #{command[:line]}\n\n")
      @ceedling[:tool_executor].exec(command[:line], command[:options])
    end
    @ceedling[:configurator].restore_config
  end

  desc 'Run Valgrind for a single test or executable ([*] real test or source file name, no path).'
  task :* do
    message = "\nOops! '#{VALGRIND_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: rake #{VALGRIND_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts(message)
  end

  # use a rule to increase efficiency for large projects
  # valgrind test tasks by regex
  rule(/^#{VALGRIND_TASK_ROOT}\S+$/ => [
         proc do |task_name|
           test = task_name.sub(/#{VALGRIND_TASK_ROOT}/, '')
           test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
           @ceedling[:file_finder].find_test_from_file_path(test)
         end
       ]) do test
    @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
    executable = @ceedling[:file_path_utils].form_test_executable_filepath(test.source)
    command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
    @ceedling[:streaminator].stdout_puts("\nINFO: #{command[:line]}\n\n")
    @ceedling[:tool_executor].exec(command[:line], command[:options])
    @ceedling[:configurator].restore_config
  end
end