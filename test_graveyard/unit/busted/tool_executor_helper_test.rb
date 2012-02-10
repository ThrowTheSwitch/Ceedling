require File.dirname(__FILE__) + '/../unit_test_helper'
require 'tool_executor_helper'


class ToolExecutorHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:verbosinator, :stream_wrapper)
    @tool_executor_helper = ToolExecutorHelper.new(objects)
  end

  def teardown
  end
  
  
  should "print no happy results" do
    # non-zero (fail) exit code
    shell_result = {:output => 'la la la. connect the dots.', :exit_code => 1}
    @tool_executor_helper.print_happy_results("", shell_result)

    # zero exit code but insufficent verbosity settings
    shell_result = {:output => "pee wee's playhouse", :exit_code => 0}
    @verbosinator.expects.should_output?(Verbosity::OBNOXIOUS).returns(false)
    @tool_executor_helper.print_happy_results("tool.exe", shell_result)
  end

  should "print happy results with response" do
    # zero exit code (success) and sufficent verbosity settings
    shell_result = {:output => "gcc blather", :exit_code => 0}
    @verbosinator.expects.should_output?(Verbosity::OBNOXIOUS).returns(true)
    
    @stream_wrapper.expects.stdout_puts("> Shell executed command:")
    @stream_wrapper.expects.stdout_puts("gcc -Iproject/source file.c -o file.out")
    @stream_wrapper.expects.stdout_puts("> Produced response:")
    @stream_wrapper.expects.stdout_puts("gcc blather")
    @stream_wrapper.expects.stdout_puts('')
    @stream_wrapper.expects.stdout_flush
    
    @tool_executor_helper.print_happy_results("gcc -Iproject/source file.c -o file.out", shell_result)
  end

  should "print happy results with no response" do
    # zero exit code (success) and sufficent verbosity settings
    shell_result = {:output => "", :exit_code => 0}
    @verbosinator.expects.should_output?(Verbosity::OBNOXIOUS).returns(true)
    
    @stream_wrapper.expects.stdout_puts("> Shell executed command:")
    @stream_wrapper.expects.stdout_puts("gcc -Iproject/source file.c -o file.out")
    @stream_wrapper.expects.stdout_puts('')
    @stream_wrapper.expects.stdout_flush
    
    @tool_executor_helper.print_happy_results("gcc -Iproject/source file.c -o file.out", shell_result)
  end


  should "print no error results" do
    # zero (success) exit code
    shell_result = {:output => 'here he comes to save the day!', :exit_code => 0}
    @tool_executor_helper.print_error_results("", shell_result)

    # non-zero exit code but insufficent verbosity settings
    shell_result = {:output => "mighty mouse", :exit_code => 1}
    @verbosinator.expects.should_output?(Verbosity::ERRORS).returns(false)
    @tool_executor_helper.print_error_results("cmd.exe", shell_result)
  end

  should "print error results with response" do
    # non-zero exit code (fail) and sufficent verbosity settings
    shell_result = {:output => "coverage: 56%", :exit_code => 99}
    @verbosinator.expects.should_output?(Verbosity::ERRORS).returns(true)
    
    @stream_wrapper.expects.stderr_puts("ERROR: Shell command failed.")
    @stream_wrapper.expects.stderr_puts("> Shell executed command:")
    @stream_wrapper.expects.stderr_puts("bullseye.exe project/build/output")
    @stream_wrapper.expects.stderr_puts("> Produced response:")
    @stream_wrapper.expects.stderr_puts("coverage: 56%")
    @stream_wrapper.expects.stderr_puts("> And exited with status: [99].")
    @stream_wrapper.expects.stderr_puts('')
    @stream_wrapper.expects.stderr_flush
    
    @tool_executor_helper.print_error_results("bullseye.exe project/build/output", shell_result)
  end

  should "print error results with no response" do
    # non-zero exit code (fail) and sufficent verbosity settings
    shell_result = {:output => "", :exit_code => 21}
    @verbosinator.expects.should_output?(Verbosity::ERRORS).returns(true)
    
    @stream_wrapper.expects.stderr_puts("ERROR: Shell command failed.")
    @stream_wrapper.expects.stderr_puts("> Shell executed command:")
    @stream_wrapper.expects.stderr_puts("bullseye.exe project/build/output")
    @stream_wrapper.expects.stderr_puts("> And exited with status: [21].")
    @stream_wrapper.expects.stderr_puts('')
    @stream_wrapper.expects.stderr_flush
    
    @tool_executor_helper.print_error_results("bullseye.exe project/build/output", shell_result)
  end

end

