

rule(/#{PROJECT_TEST_FILE_PREFIX}#{'.+'+TEST_RUNNER_FILE_SUFFIX}#{'\\'+EXTENSION_SOURCE}$/ => [
    proc do |task_name|
      return @ceedling[:file_finder].find_test_from_runner_path(task_name)
    end
  ]) do |runner|
  @ceedling[:generator].generate_test_runner(runner.source, runner.name)
end


rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      return @ceedling[:file_finder].find_compilation_input_file(task_name)
    end
  ]) do |object|
  @ceedling[:generator].generate_object_file(TOOLS_TEST_COMPILER, object.source, object.name)
end


rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_EXECUTABLE}$/) do |bin_file|
  @ceedling[:generator].generate_executable_file(TOOLS_TEST_LINKER, bin_file.prerequisites, bin_file.name)
end


rule(/#{PROJECT_TEST_RESULTS_PATH}\/#{'.+\\'+EXTENSION_TESTPASS}$/ => [
     proc do |task_name|
       return @ceedling[:file_path_utils].form_test_executable_filepath(task_name)
     end
  ]) do |test_result|
  @ceedling[:generator].generate_test_results(TOOLS_TEST_FIXTURE, test_result.source, test_result.name)
end

