# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Store functions and variables helping to parse debugger output and
# prepare output understandable by report generators
class GeneratorTestResultsBacktrace
  constructor :configurator, :tool_executor

  def setup()
    @new_line_tag = '$$$'
    @colon_tag = '!!!'

    @RESULTS_COLLECTOR = Struct.new(:passed, :failed, :ignored, :output, keyword_init:true)
  end

  def do_simple(filename, executable, shell_result, test_cases)
    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    # Revise test case list with any matches and excludes and iterate
    test_cases = filter_test_cases( test_cases )
    test_cases.each do |test_case|
      # Build the test fixture to run with our test case of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_test_fixture_simple_backtrace, [],
        executable,
        test_case[:test]
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      test_output = ''

      crash_result = @tool_executor.exec( command )

      # Successful test result
      if (crash_result[:output] =~ /:(PASS|FAIL|IGNORE):?/)
        test_output = crash_result[:output]
      # Crash case
      else
        test_output = "#{filename}:1:#{test_case[:name]}:FAIL:#{crash_result[:output]}"
      end

      # Sum execution time for each test case
      # Note: Running tests serpatately increases total execution time)
      shell_result[:time] += crash_result[:time].to_f()

      # Process single test case stats
      case test_output
      # Success test case
      when /(^#{filename}.+:PASS\s*$)/
        test_case_results[:passed]  += 1
        test_output = $1 # Grab regex match

      # Ignored test case
      when /(^#{filename}.+:IGNORE\s*$)/
        test_case_results[:ignored] += 1
        test_output = $1 # Grab regex match

      when /(^#{filename}.+:FAIL(:.+)?\s*$)/
        test_case_results[:failed]  += 1
        test_output = $1 # Grab regex match

      else # Crash failure case
        test_case_results[:failed]  += 1
        test_output = "ERR:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test Case Crashed"
      end

      # Collect up real and stand-in test results output
      test_case_results[:output].append( test_output )
    end

    # Reset shell result exit code and output
    shell_result[:exit_code] = test_case_results[:failed]
    shell_result[:output] =
      regenerate_test_executable_stdout(
        total:   test_cases.size(),
        ignored: test_case_results[:ignored],
        failed:  test_case_results[:failed],
        output:  test_case_results[:output]
      )

    return shell_result
  end

  # Support function to collect backtrace from gdb.
  # If test_runner_cmdline_args is set, function it will try to run each of test separately
  # and create output String similar to non segmentation fault execution but with notification
  # test with segmentation fault as failure
  #
  # @param [hash, #shell_result] - output shell created by calling @tool_executor.exec
  # @return hash - updated shell_result passed as argument
  def do_gdb(filename, executable, shell_result, test_cases)
    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    test_cases = filter_test_cases( test_cases )

    # Revise test case list with any matches and excludes and iterate
    test_cases.each do |test_case|
      # Build the test fixture to run with our test case of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_backtrace_reporter, [],
        executable,
        test_case[:test]
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      crash_result = @tool_executor.exec( command )

      test_output = crash_result[:output]

      # Sum execution time for each test case
      # Note: Running tests serpatately increases total execution time)
      shell_result[:time] += crash_result[:time].to_f()

      # Process successful single test case runs
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
        # Collect file_name and line in which crash occurred
        m = test_output.match /#{test_case[:test]}\s*\(\)\sat\s.*:(\d+)\n/
        if m          
          # Line number
          line = m[1]

          crash_report = filter_gdb_test_report( test_output, test_case[:test], filename )

          # Replace:
          # - '\n' by @new_line_tag to make gdb output flat
          # - ':' by @colon_tag to avoid test results problems
          # to enable parsing output for default generator_test_results regex
          test_output = crash_report.gsub("\n", @new_line_tag).gsub(':', @colon_tag)
          test_output = "#{filename}:#{line}:#{test_case[:test]}:FAIL: Test Case Crashed >> #{test_output}"
        else
          test_output = "ERR:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test Case Crashed"
        end

        # Mark test as failure
        test_case_results[:failed] += 1
      end
      test_case_results[:output].append("#{test_output}\r\n")
    end

    # Reset shell result exit code and output
    shell_result[:exit_code] = test_case_results[:failed]
    shell_result[:output] =
      regenerate_test_executable_stdout(
        total:   test_cases.size(),
        ignored: test_case_results[:ignored],
        failed:  test_case_results[:failed],
        output:  test_case_results[:output]
      )
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

  def filter_gdb_test_report( report, test_case, filename )
    lines = report.split( "\n" )

    report_start_index = 0
    report_end_index = 0

    # Find last occurrence of `test_case() at filename`
    lines.each_with_index do |line, index|
      if line =~ /#{test_case}.+at.+#{filename}/
        report_end_index = index
      end
    end

    # Work up the report to find the top of the containing text block
    report_end_index.downto(0).to_a().each do |index|
      if lines[index].empty?
        # Look for a blank line, and adjust index to last text line
        report_start_index = (index + 1)
        break
      end
    end

    length = (report_end_index - report_start_index) + 1

    return lines[report_start_index, length].join( "\n" )
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

  # TODO: When :gdb handling updates finished, refactor to use equivalent method in GeneratorTestResults
  def regenerate_test_executable_stdout(total:, failed:, ignored:, output:[])
    values = {
      :total => total,
      :failed => failed,
      :ignored => ignored,
      :output => output.map {|line| line.strip()}.join("\n"),
      :result => (failed > 0) ? 'FAIL' : 'OK'
    }

    return UNITY_TEST_RESULTS_TEMPLATE % values
  end

end
