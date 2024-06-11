# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Store functions and variables helping to parse debugger output and
# prepare output understandable by report generators
class Backtrace
  constructor :configurator, :tool_executor, :unity_utils

  def setup
    @new_line_tag = '$$$'
    @colon_tag = '!!!'
    @command_line = nil
    @test_result_collector_struct = 
      Struct.new(:passed, :failed, :ignored, :output, keyword_init: true)
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

  def do_simple(filename, command, shell_result, test_cases)
    test_case_results = @test_result_collector_struct.new(
      passed: 0,
      failed: 0,
      ignored: 0,
      output: []
    )

    # Reset time
    shell_result[:time] = 0

    filter_test_cases( test_cases ).each do |test_case|
      test_run_cmd = command.clone
      test_run_cmd[:line] += @unity_utils.additional_test_run_args( test_case[:test], :test_case )

      exec_time = 0
      test_output = ''


      crash_result = @tool_executor.exec(test_run_cmd)
      if (crash_result[:output] =~ /(?:PASS|FAIL|IGNORE)/)
        test_output = crash_result[:output]
        exec_time = crash_result[:time].to_f()
      else
        test_output = "#{filename}:1:#{test_case[:name]}:FAIL:#{crash_result[:output]}"
        exec_time = 0.0
      end

      # Concatenate execution time between tests
      # (Running tests serpatately increases total execution time)
      shell_result[:time] += exec_time

      # Concatenate successful single test runs
      m = test_output.match /([\S]+):(\d+):([\S]+):(IGNORE|PASS|FAIL:)(.*)/
      if m
        test_output = "#{m[1]}:#{m[2]}:#{m[3]}:#{m[4]}#{m[5]}"
        if test_output =~ /:PASS/
          test_case_results[:passed] += 1
        elsif test_output =~ /:IGNORE/
          test_case_results[:ignored] += 1
        elsif test_output =~ /:FAIL:/
          test_case_results[:failed] += 1
        end

      # Process crashed test case details
      else
        test_output = "ERR:#{test_case[:line_number]}:#{test_case[:test]}:FAIL:Test Case Crashed"

        # Mark test as failure
        test_case_results[:failed] += 1
      end
      test_case_results[:output].append("#{test_output}\r\n")
    end

    template = "\n-----------------------\n" \
               "\n#{(test_case_results[:passed] + \
                     test_case_results[:failed] + \
                     test_case_results[:ignored])} " \
                "Tests #{test_case_results[:failed]} " \
                "Failures #{test_case_results[:ignored]} Ignored\n\n"

    template += if test_case_results[:failed] > 0
                  "FAIL\n"
                else
                  "OK\n"
                end
    shell_result[:output] = test_case_results[:output].join('') + template

    return shell_result
  end

  # Support function to collect backtrace from gdb.
  # If test_runner_cmdline_args is set, function it will try to run each of test separately
  # and create output String similar to non segmentation fault execution but with notification
  # test with segmentation fault as failure
  #
  # @param [hash, #shell_result] - output shell created by calling @tool_executor.exec
  # @return hash - updated shell_result passed as argument
  def gdb_output_collector(shell_result, test_cases)
    test_case_result_collector = @test_result_collector_struct.new(
      passed: 0,
      failed: 0,
      ignored: 0,
      output: []
    )

    # Reset time
    shell_result[:time] = 0

    test_case_list_to_execute = filter_test_cases( test_cases )
    test_case_list_to_execute.each do |test_case|
      test_run_cmd = @command_line.clone
      test_run_cmd_with_args = test_run_cmd[:line] + @unity_utils.additional_test_run_args( test_case[:test], :test_case )
      test_output, exec_time = collect_cmd_output_with_gdb(test_run_cmd, test_run_cmd_with_args, test_case[:test])

      # Concatenate execution time between tests
      # (Running tests serpatately increases total execution time)
      shell_result[:time] += exec_time

      # Concatenate successful single test runs
      m = test_output.match /([\S]+):(\d+):([\S]+):(IGNORE|PASS|FAIL:)(.*)/
      if m
        test_output = "#{m[1]}:#{m[2]}:#{m[3]}:#{m[4]}#{m[5]}"
        if test_output =~ /:PASS/
          test_case_result_collector[:passed] += 1
        elsif test_output =~ /:IGNORE/
          test_case_result_collector[:ignored] += 1
        elsif test_output =~ /:FAIL:/
          test_case_result_collector[:failed] += 1
        end

      # Process crashed test case details
      else
        # Collect file_name and line in which crash occurred
        m = test_output.match /#{test_case[:test]}\s*\(\)\sat\s(.*):(\d+)\n/
        if m
          # Remove path from file_name
          file_name = m[1].to_s.split('/').last.split('\\').last
          
          # Line number
          line = m[2]

          # Replace:
          # - '\n' by @new_line_tag to make gdb output flat
          # - ':' by @colon_tag to avoid test results problems
          # to enable parsing output for default generator_test_results regex
          # test_output = test_output.gsub("\n", @new_line_tag).gsub(':', @colon_tag)
          test_output = "#{file_name}:#{line}:#{test_case[:test]}:FAIL: #{test_output}"
        else
          test_output = "ERR:#{test_case[:line_number]}:#{test_case[:test]}:FAIL:Test Case Crashed"
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

    return shell_result
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

  ### Private ###
  private

  # Filter list of test cases:
  #  --test_case
  #  --exclude_test_case
  #
  # @return Array - list of the test_case hashses {:test, :line_number}
  def filter_test_cases(test_cases)
    _test_cases = test_cases.clone 

    # Filter tests which contain test_case_name passed by `--test_case` argument
    if !@configurator.include_test_case.empty?
      _test_cases.delete_if { |i| !(i[:test] =~ /#{@configurator.include_test_case}/) }
    end

    # Filter tests which contain test_case_name passed by `--exclude_test_case` argument
    if !@configurator.exclude_test_case.empty?
      _test_cases.delete_if { |i| i[:test] =~ /#{@configurator.exclude_test_case}/ }
    end

    return _test_cases
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

end
