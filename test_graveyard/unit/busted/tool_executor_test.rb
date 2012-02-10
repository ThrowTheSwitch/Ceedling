require File.dirname(__FILE__) + '/../unit_test_helper'
require 'tool_executor'
require 'yaml'


NIL_GLOBAL_CONSTANT = nil

class ToolExecutorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :tool_executor_helper, :streaminator, :system_wrapper)
    @tool_executor = ToolExecutor.new(objects)
  end

  def teardown
  end
  

  ######## Build Command Line #########

  should "build a command line that contains only an executable if no arguments or blank arguments provided" do
    
    yaml1 = %Q[
    :tool1:
      :name: test_compiler
      :executable: tool.exe
      :arguments:
    ].left_margin(0)
    config1 = YAML.load(yaml1)

    yaml2 = %Q[
    :tool2:
      :name: test_compiler
      :executable: tool.exe
      :arguments:
        -
        - ' '
    ].left_margin(0)
    config2 = YAML.load(yaml2)
    
    assert_equal('tool.exe', @tool_executor.build_command_line(config1[:tool1]))
    assert_equal('tool.exe', @tool_executor.build_command_line(config2[:tool2]))
  end


  should "build a command line where the executable is specified by argument parameter input replacement" do
    
    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: ${1}
      :arguments:
        - '> ${2}'
    ].left_margin(0)
    config = YAML.load(yaml)
    
    assert_equal(
      'a_tool > files/build/tmp/file.out',
      @tool_executor.build_command_line(config[:tool], 'a_tool', 'files/build/tmp/file.out'))
      
    assert_equal(
      'test.exe > results.out',
      @tool_executor.build_command_line(config[:tool], 'test.exe', 'results.out'))      
  end


  should "build a command line where the executable is specified by argument parameter input replacement and ruby string substitution" do

    # use funky string construction to prevent ruby from performing actual string substitution we're simulating
    filepath_string = "\#{" + "File.join(A_PATH, '${2}'}"
    
    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: ${1}
      :arguments:
        - "> #{filepath_string}"
    ].left_margin(0)
    config = YAML.load(yaml)

    @system_wrapper.expects.eval("> \#{" + "File.join(A_PATH, 'file.out'}").returns('> files/build/tmp/file.out')
    @system_wrapper.expects.eval("> \#{" + "File.join(A_PATH, 'results.out'}").returns('> files/build/tmp/results.out')
    
    assert_equal(
      'a_tool > files/build/tmp/file.out',
      @tool_executor.build_command_line(config[:tool], 'a_tool', 'file.out'))
      
    assert_equal(
      'test.exe > files/build/tmp/results.out',
      @tool_executor.build_command_line(config[:tool], 'test.exe', 'results.out'))      
  end


  should "complain when building a command line if tool executable is specified with a replacement parameter but referenced input is nil" do
    
    yaml = %Q[
    :tool:
      :name: tool_sample
      :executable: ${1}
      :arguments: []
    ].left_margin(0)
    config = YAML.load(yaml)
    
    @streaminator.expects.stderr_puts("ERROR: Tool 'tool_sample' expected valid argument data to accompany replacement operator ${1}.", Verbosity::ERRORS)
    
    assert_raise(RuntimeError) { @tool_executor.build_command_line(config[:tool], nil) }
  end


  should "build a command line from simple arguments and global constants using generic '$' string replacement indicator" do
    
    redefine_global_constant('DEFINES_TEST', ['WALDORF', 'STATLER'])
    redefine_global_constant('COLLECTION_ALL_INCLUDE_PATHS', ['files/include', 'lib/modules/include'])
    redefine_global_constant('PROJECT_BUILD_ROOT', 'project/files/tests/build')
    
    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: hecklers.exe
      :arguments:
        - '--dlib_config config.h'
        - -D$: DEFINES_TEST
        - --no_cse
        - -I"$": COLLECTION_ALL_INCLUDE_PATHS
        - -I"$/mocks": PROJECT_BUILD_ROOT
        - --no_unroll
    ].left_margin(0)
    config = YAML.load(yaml)
    
    command_line = 'hecklers.exe --dlib_config config.h -DWALDORF -DSTATLER --no_cse -I"files/include" -I"lib/modules/include" -I"project/files/tests/build/mocks" --no_unroll'
    
    assert_equal(command_line, @tool_executor.build_command_line(config[:tool]))
  end


  should "build a command line from simple arguments and inline yaml arrays using '$' string replacement indicator" do

    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: compiler.exe
      :arguments:
        - --no_cse
        - '--D $':
          - DIFFERENT_DEFINE
          - STILL_ANOTHER_DEFINE
        - $:
          - A
          - B
        - --a_setting
    ].left_margin(0)
    config = YAML.load(yaml)

    command_line = 'compiler.exe --no_cse --D DIFFERENT_DEFINE --D STILL_ANOTHER_DEFINE A B --a_setting'

    assert_equal(command_line, @tool_executor.build_command_line(config[:tool]))
  end


  should "build a command line with duplicates in argument array" do

    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: compiler.exe
      :arguments:
        - ${1}
        - --option1
        - --option1
        - '-D $':
          - DEFINE_A
          - DEFINE_A
        - $:
          - Z
          - Z
        - ${1}
    ].left_margin(0)
    config = YAML.load(yaml)

    command_line = 'compiler.exe arg --option1 --option1 -D DEFINE_A -D DEFINE_A Z Z arg'

    assert_equal(command_line, @tool_executor.build_command_line(config[:tool], 'arg'))
  end


  should "build a command line using ruby string substitution for simple arguments and '$' string replacement" do

    # use funky string construction to prevent ruby from performing actual string substitution we're simulating
    abc_string = "-\#{" + "['a', 'b', 'c'].join}"
    num_string = "\#{" + "s = String.new; (1..9).to_a.each {|val| s += val.to_s}}"
    sym_string = "\#{" + "\'*!~\'.reverse}"

    @system_wrapper.expects.eval(abc_string).returns('-abc')
    @system_wrapper.expects.eval(num_string).returns('123456789')
    @system_wrapper.expects.eval(sym_string).returns('~!*')

    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: compiler.exe
      :arguments:
        - "#{abc_string}"
        - '--i $': "#{num_string}"
        - '--o $':
          - "#{sym_string}"
    ].left_margin(0)
    config = YAML.load(yaml)

    command_line = 'compiler.exe -abc --i 123456789 --o ~!*'

    assert_equal(command_line, @tool_executor.build_command_line(config[:tool]))
  end


  should "build a command line from simple arguments (including non-strings), inline yaml arrays, and input/output specifiers using string replacement indicators" do

    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: compiler.exe
      :arguments:
        - --no_cse
        - '-flag-${3}'
        - ${1}
        - '-D$':
          - ELIGHT
          - ELICIOUS
        - '-verbose:${4}'
        - '-o ${2}'
    ].left_margin(0)
    config = YAML.load(yaml)

    command_line = 'compiler.exe --no_cse -flag-1 -flag-2 process_me.c me_too.c and_me_also.c -DELIGHT -DELICIOUS -verbose:5 -o processed.o'

    assert_equal(command_line, @tool_executor.build_command_line(config[:tool], ['process_me.c', 'me_too.c', 'and_me_also.c'], 'processed.o', [1, 2], 5))
  end


  should "build a command line without replacing an escaped string replacement indicator" do

    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: program
      :arguments:
        - --cse=\\$abc
        - '-\\$D$':
          - ELIGHT
          - ELICIOUS
        - '-o ${2}.\\$'
    ].left_margin(0)
    config = YAML.load(yaml)

    command_line = 'program --cse=$abc -$DELIGHT -$DELICIOUS -o processed1.$ -o processed2.$'

    assert_equal(command_line, @tool_executor.build_command_line(config[:tool], nil, ['processed1', 'processed2']))
  end


  should "complain when building a command line if a referenced constant is nil" do
    
    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: tool.exe
      :arguments:
        - -x$: NIL_GLOBAL_CONSTANT
    ].left_margin(0)
    config = YAML.load(yaml)

    @streaminator.expects.stderr_puts("ERROR: Tool 'test_compiler' found constant 'NIL_GLOBAL_CONSTANT' to be nil.", Verbosity::ERRORS)

    assert_raise(RuntimeError) { @tool_executor.build_command_line(config[:tool]) }  
  end


  should "complain when building a command line if expansion elements are nil" do
    
    yaml = %Q[
    :tool:
      :name: test_compiler
      :executable: tool.exe
      :arguments:
        - -x$:
    ].left_margin(0)
    config = YAML.load(yaml)

    @streaminator.expects.stderr_puts("ERROR: Tool 'test_compiler' could not expand nil elements for format string '-x$'.", Verbosity::ERRORS)

    assert_raise(RuntimeError) { @tool_executor.build_command_line(config[:tool]) }  
  end


  should "complain when building a command line if argument replacement parameters are specified but referenced input is nil" do
    
    yaml = %Q[
    :tool:
      :name: classic_movie
      :executable: harry
      :arguments:
        - ${1}
    ].left_margin(0)
    config = YAML.load(yaml)

    @streaminator.expects.stderr_puts("ERROR: Tool 'classic_movie' expected valid argument data to accompany replacement operator ${1}.", Verbosity::ERRORS)
    
    assert_raise(RuntimeError) { @tool_executor.build_command_line(config[:tool], nil, 'sally') }  
  end

  
  should "complain when building a command line if argument replacement parameters are specified but no optional arguments are given" do
    
    yaml = %Q[
    :tools_a_tool:
      :name: take_a_dip_in_the_tool
      :executable: harry
      :arguments:
        - ${2}
    ].left_margin(0)
    config = YAML.load(yaml)

    @streaminator.expects.stderr_puts("ERROR: Tool 'take_a_dip_in_the_tool' expected valid argument data to accompany replacement operator ${2}.", Verbosity::ERRORS)
    
    assert_raise(RuntimeError) { @tool_executor.build_command_line(config[:tools_a_tool]) }  
  end

  ######## Shell Out & Execute Command #########

  should "shell out & execute command with additional arguments" do
    shell_result = {:output => 'stdout string', :exit_code => 0}
    
    @system_wrapper.expects.shell_execute('shell_command arg1 arg2').returns(shell_result)
  
    @tool_executor_helper.expects.print_happy_results('shell_command arg1 arg2', shell_result)
    @tool_executor_helper.expects.print_error_results('shell_command arg1 arg2', shell_result)
  
    assert_equal('stdout string', @tool_executor.exec(' shell_command', ['arg1', 'arg2']))
  end

  should "shell out & execute command but raise on non-zero exit code" do
    shell_result = {:output => '', :exit_code => 1}
    
    @system_wrapper.expects.shell_execute('shell_fish').returns(shell_result)
  
    @tool_executor_helper.expects.print_happy_results('shell_fish', shell_result)
    @tool_executor_helper.expects.print_error_results('shell_fish', shell_result)
  
    assert_raise(RuntimeError){ @tool_executor.exec('shell_fish') }
  end

end
