directory(VALGRIND_BUILD_OUTPUT_PATH)

CLEAN.include(File.join(VALGRIND_BUILD_OUTPUT_PATH, '*'))

CLOBBER.include(File.join(VALGRIND_BUILD_PATH, '**/*'))

task directories: [VALGRIND_BUILD_OUTPUT_PATH]

namespace VALGRIND_SYM do
  desc 'Run Valgrind for all tests'
  task all: [:prepare] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
    COLLECTION_ALL_TESTS.each do |test|
      executable = @ceedling[:file_path_utils].form_test_executable_filepath(File.join(VALGRIND_BUILD_OUTPUT_PATH, File.basename(test, @ceedling[:configurator].extension_source)), test)
      command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
      @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
      shell_result = @ceedling[:tool_executor].exec(command)
      @ceedling[:loginator].log("#{shell_result[:output]}\n")
    end
  end

  desc 'Run Valgrind for a single test or executable ([*] real test or source file name, no path).'
  task :* do
    message = "\nOops! '#{VALGRIND_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: rake #{VALGRIND_ROOT_NAME}:foo.c\n\n"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc 'Run Valgrind for tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
      matches.each do |test|
        executable = @ceedling[:file_path_utils].form_test_executable_filepath(File.join(VALGRIND_BUILD_OUTPUT_PATH, File.basename(test, @ceedling[:configurator].extension_source)), test)
        command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
        @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
        shell_result = @ceedling[:tool_executor].exec(command)
        @ceedling[:loginator].log("#{shell_result[:output]}\n")
      end
    else
      @ceedling[:loginator].log("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc 'Run Valgrind for tests whose test path contains [dir] or [dir] substring.'
  task :path, [:dir] => [:prepare] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if File.dirname(test).include?(args.dir.tr('\\', '/'))
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
      matches.each do |test|
        executable = @ceedling[:file_path_utils].form_test_executable_filepath(File.join(VALGRIND_BUILD_OUTPUT_PATH, File.basename(test, @ceedling[:configurator].extension_source)), test)
        command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
        @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
        shell_result = @ceedling[:tool_executor].exec(command)
        @ceedling[:loginator].log("#{shell_result[:output]}\n")
      end
    else
      @ceedling[:loginator].log( 'Found no tests including the given path or path component', Verbosity::ERRORS )
    end
  end

  # Use a rule to increase efficiency for large projects
  rule(/^#{VALGRIND_TASK_ROOT}\S+$/ => [ # valgrind test tasks by regex
         proc do |task_name|
            # Yield clean test name => Strip the task string, remove Rake test task prefix, and remove any code file extension
            test = task_name.strip().sub(/^#{VALGRIND_TASK_ROOT}/, '').chomp( EXTENSION_SOURCE )

            # Ensure the test name begins with a test name prefix
            test = PROJECT_TEST_FILE_PREFIX + test if not (test.start_with?( PROJECT_TEST_FILE_PREFIX ))

            # Provide the filepath for the target test task back to the Rake task
            @ceedling[:file_finder].find_test_file_from_name( test )
         end
       ]) do |test|
    @ceedling[:configurator].replace_flattened_config(@ceedling[VALGRIND_SYM].config)
    executable = @ceedling[:file_path_utils].form_test_executable_filepath(File.join(VALGRIND_BUILD_OUTPUT_PATH, File.basename(test.source, @ceedling[:configurator].extension_source)), test.source)
    command = @ceedling[:tool_executor].build_command_line(TOOLS_VALGRIND, [], executable)
    @ceedling[:loginator].log("\nINFO: #{command[:line]}\n\n")
    shell_result = @ceedling[:tool_executor].exec(command)
    @ceedling[:loginator].log("#{shell_result[:output]}\n")
  end
end
