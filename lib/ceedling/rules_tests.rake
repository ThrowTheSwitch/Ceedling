

rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      _, object = (task_name.split('+'))
      @ceedling[:file_finder].find_compilation_input_file(object)
    end
  ]) do |target|
    test, object = (target.name.split('+'))

    if (File.basename(target.source) =~ /#{EXTENSION_SOURCE}$/)
      @ceedling[:test_invoker].compile_test_component(test: test.to_sym, source: target.source, object: object)
    elsif (defined?(TEST_BUILD_USE_ASSEMBLY) && TEST_BUILD_USE_ASSEMBLY)
      @ceedling[:generator].generate_object_file(
        TOOLS_TEST_ASSEMBLER,
        OPERATION_ASSEMBLE_SYM,
        TEST_SYM,
        object.source,
        object.name )
    end
  end


# rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\'+EXTENSION_EXECUTABLE}$/) do |bin_file|
#   lib_args = @ceedling[:test_invoker].convert_libraries_to_arguments()
#   lib_paths = @ceedling[:test_invoker].get_library_paths_to_arguments()
#   @ceedling[:generator].generate_executable_file(
#     TOOLS_TEST_LINKER,
#     TEST_SYM,
#     bin_file.prerequisites,
#     bin_file.name,
#     @ceedling[:file_path_utils].form_test_build_map_filepath( bin_file.name ),
#     lib_args,
#     lib_paths )
# end


# rule(/#{PROJECT_TEST_RESULTS_PATH}\/#{'.+\\'+EXTENSION_TESTPASS}$/ => [
#     proc do |task_name|
#       @ceedling[:file_path_utils].form_test_executable_filepath(task_name)
#     end
#   ]) do |test_result|
#   @ceedling[:generator].generate_test_results(TOOLS_TEST_FIXTURE, TEST_SYM, test_result.source, test_result.name)
# end


namespace TEST_SYM do
  TOOL_COLLECTION_TEST_RULES = {
    :context        => TEST_SYM,
    :test_compiler  => TOOLS_TEST_COMPILER,
    :test_assembler => TOOLS_TEST_ASSEMBLER,
    :test_linker    => TOOLS_TEST_LINKER,
    :test_fixture   => TOOLS_TEST_FIXTURE
  }

  @ceedling[:unity_utils].create_test_runner_additional_args

  # use rules to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)
  rule(/^#{TEST_TASK_ROOT}\S+$/ => [ # test task names by regex
      proc do |task_name|
        test = task_name.sub(/#{TEST_TASK_ROOT}/, '')
        test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" if not (test.start_with?(PROJECT_TEST_FILE_PREFIX))
        @ceedling[:file_finder].find_test_from_file_path(test)
      end
  ]) do |test|
    @ceedling[:rake_wrapper][:test_deps].invoke
    @ceedling[:test_invoker].setup_and_invoke(tests:[test.source], options:{:force_run => true, :build_only => false}.merge(TOOL_COLLECTION_TEST_RULES))
  end
end

