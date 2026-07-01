# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class GeneratorTestResultsBacktrace

  constructor :configurator, :tool_executor, :generator_test_results, :file_path_utils, :file_wrapper

  def setup()
    @RESULTS_COLLECTOR = Struct.new( :passed, :failed, :ignored, :output, keyword_init:true )
  end

  # Re-runs each test case under gdb to identify which ones crashed and why.
  # Writes the full gdb transcript to a per-test-case log file and assembles a
  # terse crash label (signal + description, optional source line in backticks)
  # for each failing test case. Returns a modified shell_result with regenerated output.
  def do_gdb(filename, executable, shell_result, test_cases, context:)
    gdb_script_filepath = File.join( @configurator.project_build_tests_root, BACKTRACE_GDB_SCRIPT_FILE )

    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    test_name = File.basename( filename, '.*' )

    # Iterate on test cases
    test_cases.each do |test_case|
      # Per-test-case log file: <log_path>/<context>/<test_name>/<test_case>.gdb.log
      log_path = @file_path_utils.form_test_gdb_log( test_name, context: context, name: test_case[:test] )
      @file_wrapper.mkdir( File.dirname( log_path ) )

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
      # Note: Running tests separately increases total execution time
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

        # Append full gdb output for this test case to the log
        @file_wrapper.write( log_path, "=== #{test_case[:test]} ===\n#{crash_result[:output]}\n", 'a' )

        # Collect file_name and line in which crash occurred
        matched = crash_result[:output].match( /#{test_case[:test]}\s*\(\)\sat.+#{filename}:(\d+)\n/ )

        # If we found an error report line containing `test_case() at filename.c:###` in `gdb` output
        if matched
          # Line number
          line_number = matched[1]

          # Build terse signal label: "[SIGNAL] Description"
          signal_label = format_signal_label( crash_result[:output] )

          # Extract the offending source line (nil for assertion crashes or when unavailable)
          source_line = extract_source_line( crash_result[:output], test_case[:test], filename )

          # Unity's test executable output is line oriented.
          # Multi-line output is not possible (it looks like random `printf()` statements to the results parser).
          # "Encode" newlines in multiline string to be handled by the test results parser.
          crash_detail = source_line ? "#{NEWLINE_TOKEN}`#{source_line}`" : ''

          # Log path appears on its own encoded line so the results parser treats it separately
          test_output =
            "#{filename}:#{line_number}:#{test_case[:test]}:FAIL: Test case crashed" \
            " >> #{signal_label}" \
            "#{crash_detail}" \
            "#{NEWLINE_TOKEN}(#{log_path})"

        # Otherwise communicate that `gdb` failed to produce a usable report
        else
          test_output =
            "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: " \
            "Test case crashed (failed to extract `gdb` report)" \
            "#{NEWLINE_TOKEN}(#{log_path})"
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

  # Re-runs each test case individually to determine which ones crashed.
  # For crash cases, captures any extra output from the test binary (e.g.
  # assertion messages on stderr) and includes it in the failure report.
  # Returns a modified shell_result with regenerated output.
  def do_simple(filename, executable, shell_result, test_cases, context:)
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
      # Note: Running tests separately increases total execution time
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

        # Collect any non-result, non-blank lines (e.g. assertion messages on stderr)
        extra = extract_simple_crash_output( crash_result[:output], filename )
        test_output = "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed"
        test_output += " >> #{extra.join(NEWLINE_TOKEN)}" unless extra.empty?
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

  ### Private ###
  private

  # Builds a terse signal label from gdb output: "[SIGNAL] Description".
  # For SIGABRT, substitutes glibc assertion text when present — more
  # informative than the bare "Aborted" signal description.
  # Returns empty string if no signal line is found in output.
  def format_signal_label(output)
    m = output.match( /Program received signal (\w+), (.+)\./ )
    return '' unless m

    description = m[2].strip

    # Prefer glibc's assertion message over the bare signal description
    # when present — "Assertion 'x > 0' failed" is more informative than "Aborted"
    if (a = output.match( /\S+:\d+: \S+: Assertion `(.+)' failed\./ ))
      description = "Assertion '#{a[1]}' failed"
    end

    return "[#{m[1]}] #{description}"
  end

  # Extracts the offending source line from gdb output.
  # Looks for a `<line_num>\t<code>` line immediately following the
  # crash location line (`test_case() at filename:line`).
  # Returns nil for assertion crashes (description is already informative)
  # and nil when no source line is available in the gdb output.
  def extract_source_line(output, test_case, filename)
    # Assertion crashes: description is already informative — no source line needed
    return nil if output.match?( /\S+:\d+: \S+: Assertion `.+' failed\./ )

    # Find <line_num>\t<code> immediately following test_case() at filename:line
    m = output.match( /#{Regexp.escape(test_case)}.+#{Regexp.escape(filename)}:\d+\n(\d+)\t(.+)/ )
    return m ? m[2].strip : nil
  end

  # Extracts lines from do_simple crash output that are not Unity test result
  # lines (PASS/FAIL/IGNORE) and not blank. These are typically stderr output
  # from the crashed test binary — assertion messages, abort text, etc.
  def extract_simple_crash_output(output, filename)
    output.lines.filter_map do |line|
      line = line.strip
      next if line.empty?
      next if line =~ /^#{filename}.+:(PASS|FAIL|IGNORE)/
      line
    end
  end

end
