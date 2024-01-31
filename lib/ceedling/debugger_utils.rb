# The debugger utils class,
# Store functions and variables helping to parse debugger output and
# prepare output understandable by report generators
class DebuggerUtils
  constructor :configurator,
              :tool_executor,
              :unity_utils

  def setup
    @new_line_tag = '$$$'
    @colon_tag = '!!!'
    @command_line = nil
    @test_result_collector_struct = Struct.new(:passed, :failed, :ignored,
                                               :output, keyword_init: true)
  end

  # Copy original command line generated from @tool_executor.build_command_line
  # to use command line without command line extra args not needed by debugger
  #
  # @param [hash, #command] - Command line generated from @tool_executor.build_command_line
  def configure_debugger(command)
    # Make a clone of clean command hash
    # for further calls done for collecting segmentation fault
    if @configurator.project_config_hash[:project_use_backtrace] &&
       @configurator.project_config_hash[:test_runner_cmdline_args]
      @command_line = command.clone
    elsif @configurator.project_config_hash[:project_use_backtrace]
      # If command_lines are not enabled, do not clone but create reference to command
      # line
      @command_line = command
    end
  end

  # Execute test_runner file under gdb and return:
  # - output -> stderr and stdout
  # - time -> execution of single test
  #
  # @param [hash, #command] - Command line generated from @tool_executor.build_command_line
  # @return [String, #output] - output from binary execution
  # @return [Float, #time] - time execution of the binary file
  def collect_cmd_output_with_gdb(command, cmd, test_case=nil)
    gdb_file_name = @configurator.project_config_hash[:tools_backtrace_reporter][:executable]
    gdb_extra_args = @configurator.project_config_hash[:tools_backtrace_reporter][:arguments]
    gdb_extra_args = gdb_extra_args.join(' ')

    gdb_exec_cmd = command.clone 
    gdb_exec_cmd[:line] = "#{gdb_file_name} #{gdb_extra_args} #{cmd}"
    crash_result = @tool_executor.exec(gdb_exec_cmd)
    if (crash_result[:exit_code] == 0) and (crash_result[:output] =~ /(?:PASS|FAIL|IGNORE)/)
      [crash_result[:output], crash_result[:time].to_f]
    else
      ["#{gdb_file_name.split(/\w+/)[0]}:1:#{test_case || 'test_Unknown'}:FAIL:#{crash_result[:output]}", 0.0]
    end
  end

  # Collect list of test cases from test_runner
  # and apply filters basing at passed :
  # --test_case
  # --exclude_test_case
  # input arguments
  #
  # @param [hash, #command] - Command line generated from @tool_executor.build_command_line
  # @return Array - list of the test_cases defined in test_file_runner
  def collect_list_of_test_cases(command)
    all_test_names = command.clone 
    all_test_names[:line] += @unity_utils.additional_test_run_args('', 'list_test_cases')
    test_list = @tool_executor.exec(all_test_names)
    test_runner_tc = test_list[:output].split("\n").drop(1)

    # Clean collected test case names
    # Filter tests which contain test_case_name passed by `--test_case` argument
    if ENV['CEEDLING_INCLUDE_TEST_CASE_NAME']
      test_runner_tc.delete_if { |i| !(i =~ /#{ENV['CEEDLING_INCLUDE_TEST_CASE_NAME']}/) }
    end

    # Filter tests which contain test_case_name passed by `--exclude_test_case` argument
    if ENV['CEEDLING_EXCLUDE_TEST_CASE_NAME']
      test_runner_tc.delete_if { |i| i =~ /#{ENV['CEEDLING_EXCLUDE_TEST_CASE_NAME']}/ }
    end

    test_runner_tc
  end

  # Update stderr output stream to auto, to collect segmentation fault for
  # test execution with gcov tool
  #
  # @param [hash, #command] - Command line generated from @tool_executor.build_command_line
  def enable_gcov_with_gdb_and_cmdargs(command)
    if @configurator.project_config_hash[:project_use_backtrace] &&
       @configurator.project_config_hash[:test_runner_cmdline_args]
       command[:options][:stderr_redirect] = if [:none, StdErrRedirect::NONE].include? @configurator.project_config_hash[:tools_backtrace_reporter][:stderr_redirect]
                                               DEFAULT_BACKTRACE_TOOL[:stderr_redirect]
                                             else
                                               @configurator.project_config_hash[:tools_backtrace_reporter][:stderr_redirect]
                                             end
    end
  end

  # Support function to collect backtrace from gdb.
  # If test_runner_cmdline_args is set, function it will try to run each of test separately
  # and create output String similar to non segmentation fault execution but with notification
  # test with segmentation fault as failure
  #
  # @param [hash, #shell_result] - output shell created by calling @tool_executor.exec
  # @return hash - updated shell_result passed as argument
  def gdb_output_collector(shell_result)
    test_case_result_collector = @test_result_collector_struct.new(
      passed: 0,
      failed: 0,
      ignored: 0,
      output: []
    )

    # Reset time
    shell_result[:time] = 0

    test_case_list_to_execute = collect_list_of_test_cases(@command_line)
    test_case_list_to_execute.each do |test_case_name|
      test_run_cmd = @command_line.clone
      test_run_cmd_with_args = test_run_cmd[:line] + @unity_utils.additional_test_run_args(test_case_name, 'test_case')
      test_output, exec_time = collect_cmd_output_with_gdb(test_run_cmd, test_run_cmd_with_args, test_case_name)

      # Concatenate execution time between tests
      # running tests serpatatelly might increase total execution time
      shell_result[:time] += exec_time

      # Concatenate test results from single test runs, which not crash
      # to create proper output for further parser
      if test_output =~ /([\S]+):(\d+):([\S]+):(IGNORE|PASS|FAIL:)(.*)/
        test_output = "#{Regexp.last_match(1)}:#{Regexp.last_match(2)}:#{Regexp.last_match(3)}:#{Regexp.last_match(4)}#{Regexp.last_match(5)}"
        if test_output =~ /:PASS/
          test_case_result_collector[:passed] += 1
        elsif test_output =~ /:IGNORE/
          test_case_result_collector[:ignored] += 1
        elsif test_output =~ /:FAIL:/
          test_case_result_collector[:failed] += 1
        end
      else
        # <-- Parse Segmentatation Fault output section -->
        
        # Withdraw test_name from gdb output
        test_name = if test_output =~ /<(.*)>/
                      Regexp.last_match(1)
                    else
                      ''
                    end

        # Collect file_name and line in which Segmentation fault have his beginning
        if test_output =~ /#{test_name}\s\(\)\sat\s(.*):(\d+)\n/
          # Remove path from file_name
          file_name = Regexp.last_match(1).to_s.split('/').last.split('\\').last
          # Save line number
          line = Regexp.last_match(2)

          # Replace:
          # - '\n' by @new_line_tag to make gdb output flat
          # - ':' by @colon_tag to avoid test results problems
          # to enable parsing output for default generator_test_results regex
          test_output = test_output.gsub("\n", @new_line_tag).gsub(':', @colon_tag)
          test_output = "#{file_name}:#{line}:#{test_name}:FAIL: #{test_output}"
        end

        # Mark test as failure
        test_case_result_collector[:failed] += 1
      end
      test_case_result_collector[:output].append("#{test_output}\r\n")
    end

    template = "\n-----------------------\n" \
               "\n#{(test_case_result_collector[:passed] + \
                     test_case_result_collector[:failed] + \
                     test_case_result_collector[:ignored])} " \
                "Tests #{test_case_result_collector[:failed]} " \
                "Failures #{test_case_result_collector[:ignored]} Ignored\n\n"

    template += if test_case_result_collector[:failed] > 0
                  "FAIL\n"
                else
                  "OK\n"
                end
    shell_result[:output] = test_case_result_collector[:output].join('') + template

    shell_result
  end

  # Restore new line under flatten log
  #
  # @param(String, #text) - string containing flatten output log
  # @return [String, #output] - output with restored new line character
  def restore_new_line_character_in_flatten_log(text)
    if @configurator.project_config_hash[:project_use_backtrace] &&
       @configurator.project_config_hash[:test_runner_cmdline_args]
      text = text.gsub(@new_line_tag, "\n")
    end
    text
  end

  # Restore colon character under flatten log
  #
  # @param(String, #text) - string containing flatten output log
  # @return [String, #output] - output with restored colon character
  def restore_colon_character_in_flatten_log(text)
    if @configurator.project_config_hash[:project_use_backtrace] &&
       @configurator.project_config_hash[:test_runner_cmdline_args]
      text = text.gsub(@colon_tag, ':')
    end
    text
  end

  # Unflat segmentation fault log
  #
  # @param(String, #text) - string containing flatten output log
  # @return [String, #output] - output with restored colon and new line character
  def unflat_debugger_log(text)
    text = restore_new_line_character_in_flatten_log(text)
    text = restore_colon_character_in_flatten_log(text)
    text = text.gsub('"',"'") # Replace " character by ' for junit_xml reporter
    text
  end
end
