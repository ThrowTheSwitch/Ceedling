

rule(/#{PROJECT_TEST_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_OBJECT}$/ => [
    proc do |task_name|
      _, object = (task_name.split('+'))
      @ceedling[:file_finder].find_build_input_file(filepath: object, context: TEST_SYM)
    end
  ]) do |target|
    test, object = (target.name.split('+'))

    tool = TOOLS_TEST_COMPILER

    if @ceedling[:file_wrapper].extname(target.source) == EXTENSION_ASSEMBLY
      tool = TOOLS_TEST_ASSEMBLER
    end

    @ceedling[:test_invoker].compile_test_component(
      tool: tool,
      test: test.to_sym,
      source: target.source,
      object: object
    )
  end

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
    @ceedling[:rake_wrapper][:directories].invoke
    @ceedling[:test_invoker].setup_and_invoke(tests:[test.source], options:{:force_run => true, :build_only => false}.merge(TOOL_COLLECTION_TEST_RULES))
  end
end

