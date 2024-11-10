# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class GeneratorTestResultsBacktrace

  constructor :configurator, :tool_executor, :generator_test_results

  def setup()
    @RESULTS_COLLECTOR = Struct.new( :passed, :failed, :ignored, :output, keyword_init:true )
  end

  def do_simple(filename, executable, shell_result, test_cases)
    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    # Iterate on test cases
    test_cases.each do |test_case|
      # Build the test fixture to run with our test case of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_test_fixture_simple_backtrace, [],
        executable,
        test_case[:test]
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      crash_result = @tool_executor.exec( command )

      # Sum execution time for each test case
      # Note: Running tests serpatately increases total execution time)
      shell_result[:time] += crash_result[:time].to_f()

      # Process single test case stats
      case crash_result[:output]
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
        test_output = "#{filename}}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed"
      end

      # Collect up real and stand-in test results output
      test_case_results[:output] << test_output
    end

    # Reset shell result exit code and output
    shell_result[:exit_code] = test_case_results[:failed]
    shell_result[:output] =
      @generator_test_results.regenerate_test_executable_stdout(
        total:   test_cases.size(),
        ignored: test_case_results[:ignored],
        failed:  test_case_results[:failed],
        output:  test_case_results[:output]
      )

    return shell_result
  end

  def do_gdb(filename, executable, shell_result, test_cases)
    gdb_script_filepath = File.join( @configurator.project_build_tests_root, BACKTRACE_GDB_SCRIPT_FILE )

    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    # Iterate on test cases
    test_cases.each do |test_case|
      # Build the test fixture to run with our test case of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_test_backtrace_gdb, [],
        gdb_script_filepath,
        executable,
        test_case[:test]
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      crash_result = @tool_executor.exec( command )

      # Sum execution time for each test case
      # Note: Running tests serpatately increases total execution time)
      shell_result[:time] += crash_result[:time].to_f()

      test_output = ''

      # Process single test case stats
      case crash_result[:output]
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

        # Collect file_name and line in which crash occurred
        matched = crash_result[:output].match( /#{test_case[:test]}\s*\(\)\sat.+#{filename}:(\d+)\n/ )

        # If we found an error report line containing `test_case() at filename.c:###` in `gdb` output
        if matched
          # Line number
          line_number = matched[1]

          # Filter the `gdb` $stdout report to find most important lines of text
          crash_report = filter_gdb_test_report( crash_result[:output], test_case[:test], filename )

          # Unity’s test executable output is line oriented.
          # Multi-line output is not possible (it looks like random `printf()` statements to the results parser)
          # "Encode" newlines in multiline string to be handled by the test results parser.
          test_output = crash_report.gsub( "\n", NEWLINE_TOKEN )

          test_output = "#{filename}:#{line_number}:#{test_case[:test]}:FAIL: Test case crashed >> #{test_output}"

        # Otherwise communicate that `gdb` failed to produce a usable report
        else
          test_output = "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed (no usable `gdb` report)"
        end
      end

      test_case_results[:output] << test_output
    end

    # Reset shell result exit code and output
    shell_result[:exit_code] = test_case_results[:failed]
    shell_result[:output] =
      @generator_test_results.regenerate_test_executable_stdout(
        total:   test_cases.size(),
        ignored: test_case_results[:ignored],
        failed:  test_case_results[:failed],
        output:  test_case_results[:output]
      )

    return shell_result
  end

  ### Private ###
  private

  def filter_gdb_test_report(report, test_case, filename)
    #       Sample `gdb` backtrace output
    #       =============================
    #       [Thread debugging using libthread_db enabled]
    #       Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
    #
    # [1] > Program received signal SIGSEGV, Segmentation fault.
    #       0x0000555999f661fb in testCrash () at test/TestUsartModel.c:40
    # [2] > 40    uint32_t i = *nullptr;
    #       #0  0x0000555999f661fb in testCrash () at test/TestUsartModel.c:40
    #       #1  0x0000555999f674de in run_test (func=0x555999f661e7 <testCrash>, name=0x555999f6b2e0 "testCrash", line_num=37) at build/test/runners/TestUsartModel_runner.c:76
    #       #2  0x0000555999f6766b in main (argc=3, argv=0x7fff917e2c98) at build/test/runners/TestUsartModel_runner.c:117

    lines = report.split( "\n" )

    # Safe defaults to extract entire report
    report_start_index = 0                # [1]
    report_end_index   = (lines.size()-1) # [2]

    # Find line preceding last `<test_case> () at <filename>`, [2];
    # it is the offending line of code.
    # We don't need the rest of the call trace -- it's just from the runner 
    # up to the crashed test case.
    lines.each_with_index do |line, index|
      if line =~ /#{test_case}.+at.+#{filename}/
        report_end_index = (index - 1) unless (index == 0)
      end
    end

    # Work up from [2] to find top line of the containing text block, [1].
    # Go until we find a blank line; then increment index back down a line.
    # This lops off any unneeded preamble.
    report_end_index.downto(0).to_a().each do |index|
      if lines[index].empty?
        # Look for a blank line and adjust index to next line of text
        report_start_index = (index + 1)
        break
      end
    end

    length = (report_end_index - report_start_index) + 1

    # Reconstitute the report from the extracted lines
    return lines[report_start_index, length].join( "\n" )
  end

end
