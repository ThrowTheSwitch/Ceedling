

rule(/#{PROJECT_TEST_FILE_PREFIX}#{'.+'+TEST_RUNNER_FILE_SUFFIX}#{'\\'+EXTENSION_SOURCE}$/ => [
    proc do |task_name|
      return @objects[:file_finder].find_test_from_runner_path(task_name)
    end  
  ]) do |runner|
  @objects[:generator].generate_test_runner(runner.source, runner.name)
end


rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      return @objects[:file_finder].find_compilation_input_file(task_name)
    end  
  ]) do |object|
  @objects[:generator].generate_object_file(object.source, object.name)
end


rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_EXECUTABLE}$/) do |bin_file|
  @objects[:generator].generate_executable_file(bin_file.prerequisites, bin_file.name)
end


rule(/#{PROJECT_TEST_RESULTS_PATH}\/#{'.+\\'+EXTENSION_TESTPASS}$/ => [
     proc do |task_name|
       return @objects[:file_path_utils].form_executable_filepath(task_name)
     end
  ]) do |test_result|
  @objects[:generator].generate_test_results(test_result.source, test_result.name)
end

