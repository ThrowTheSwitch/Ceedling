# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class GeneratorTestResultsBacktrace

  constructor :configurator, :tool_executor, :generator_test_results, :generator_helper,
              :file_path_utils, :file_wrapper, :loginator

  def setup()
    @RESULTS_COLLECTOR = Struct.new( :passed, :failed, :ignored, :output, keyword_init:true )
    # Alias, matching Generator's own convention for the same dependency.
    @helper = @generator_helper
  end

  # Re-runs each test case (or, for a parameterized test, each group of parameterized
  # cases -- see `group_test_cases`) under gdb to identify which one(s) crashed and why.
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

    # True once some retry group has actually shown crash evidence of its own -- an
    # unresolved member, or (below) a group whose real status contradicts a fully clean
    # set of matches. If this stays false across every group, the whole diagnostic never
    # reproduced or attributed the crash the main run already detected, and none of it
    # can be trusted -- see the fallback after the loop.
    any_group_crashed = false

    # Iterate on test cases, one sub-process run per group (see `group_test_cases`)
    group_test_cases( test_cases ).each do |group|
      # Build the test fixture to run with our test case (or parameterized group) of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_test_backtrace_gdb, [],
        gdb_script_filepath,
        executable,
        unity_filter_arg( group )
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      crash_result = @tool_executor.exec( command )

      # Sum execution time for each sub-process run
      # Note: Running tests separately increases total execution time
      shell_result[:time] += crash_result[:time].to_f()

      # Buffered separately from test_case_results and only merged in afterward, since
      # the status check below can still discard every match here in favor of a crash
      # attribution, once the whole group has been seen.
      group_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )
      unresolved = []

      # Attribute each group member its own real result line, if Unity printed one
      group.each do |test_case|
        case crash_result[:output]
        # Success test case
        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:PASS\s*$)/
          group_results[:passed]  += 1
          group_results[:output] << $1

        # Ignored test case
        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:IGNORE\s*$)/
          group_results[:ignored] += 1
          group_results[:output] << $1

        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:FAIL(:.+)?\s*$)/
          group_results[:failed]  += 1
          group_results[:output] << $1

        # No result line for this member -- either it crashed, or it never got to run
        # because an earlier member in this same group crashed. Resolved below.
        else
          unresolved << test_case
        end
      end

      if !unresolved.empty?
        # Prefer whichever unresolved member's own C symbol is actually named in the gdb
        # backtrace (works regardless of position in the group); fall back to the first
        # unresolved member if no member's symbol can be found in the transcript (e.g. a
        # brief crash report with no frame information at all).
        crashed_case = unresolved.find do |tc|
          crash_result[:output].match?( /#{Regexp.escape(tc[:symbol])}\s*\(\)\sat/ )
        end
        crashed_case ||= unresolved.first

        # Per-test-case log file: <log_path>/<context>/<test_name>/<test_case>.gdb.log
        log_path = @file_path_utils.form_test_gdb_log( test_name, context: context, name: crashed_case[:test] )
        @file_wrapper.mkdir( File.dirname( log_path ) )
        @file_wrapper.write( log_path, "=== #{crashed_case[:test]} ===\n#{crash_result[:output]}\n", 'a' )

        unresolved.each do |test_case|
          group_results[:failed] += 1

          if !test_case.equal?( crashed_case )
            # An earlier case in this same parameterized group already crashed the
            # process -- this member never got a chance to run.
            group_results[:output] <<
              "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: " \
              "Test case not run -- an earlier case in this parameterized test group crashed"
            next
          end

          # Collect file_name and line in which crash occurred.
          # Match against the actual C symbol (`:symbol`), not the human-facing test name
          # (`:test`): a parameterized test case crashes inside a generated wrapper function
          # (`runner_args<N>_<test>`), not a function literally named `<test>(<args>)`.
          matched = crash_result[:output].match( /#{Regexp.escape(test_case[:symbol])}\s*\(\)\sat.+#{filename}:(\d+)\n/ )

          # If we found an error report line containing `test_case() at filename.c:###` in `gdb` output
          if matched
            # Line number
            line_number = matched[1]

            # Build terse signal label: "[SIGNAL] Description"
            signal_label = format_signal_label( crash_result[:output] )

            # Extract the offending source line (nil for assertion crashes or when unavailable)
            source_line = extract_source_line( crash_result[:output], test_case[:symbol], filename )

            # Unity's test executable output is line oriented.
            # Multi-line output is not possible (it looks like random `printf()` statements to the results parser).
            # "Encode" newlines in multiline string to be handled by the test results parser.
            crash_detail = source_line ? "#{NEWLINE_TOKEN}`#{source_line}`" : ''

            # Log path appears on its own encoded line so the results parser treats it separately
            group_results[:output] <<
              "#{filename}:#{line_number}:#{test_case[:test]}:FAIL: Test case crashed" \
              " >> #{signal_label}" \
              "#{crash_detail}" \
              "#{NEWLINE_TOKEN}(#{log_path})"

          # Try to extract a useful label even when no crash location frame was found.
          # A brief Windows assertion failure may report only the assertion text without frames.
          else
            label = format_signal_label( crash_result[:output] )

            if !label.empty?
              group_results[:output] <<
                "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed" \
                " >> #{label}" \
                "#{NEWLINE_TOKEN}(#{log_path})"
            else
              group_results[:output] <<
                "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: " \
                "Test case crashed (failed to extract `gdb` report)" \
                "#{NEWLINE_TOKEN}(#{log_path})"
            end
          end
        end
      end

      # Every member in this group resolved via a matched result line -- but gdb
      # normally exits successfully after handling a crash regardless of what happened
      # to the debuggee, so a clean-looking group here is a weaker signal than it is for
      # `do_simple`. Still checked for the same reason: a diagnostic retry's own real
      # status contradicting a fully clean set of matches is never trustworthy, whatever
      # tool produced it.
      if unresolved.empty? && @helper.test_crash?( filename, executable, crash_result )
        group_results = @RESULTS_COLLECTOR.new(
          passed: 0, ignored: 0, failed: group.size,
          output: group.map { |test_case|
            "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed" \
            " >> diagnostic retry's own exit status contradicts its reported clean result"
          }
        )
        unresolved = group # non-empty now, marks this group as having shown crash evidence
      end

      any_group_crashed ||= !unresolved.empty?

      test_case_results[:passed]  += group_results[:passed]
      test_case_results[:ignored] += group_results[:ignored]
      test_case_results[:failed]  += group_results[:failed]
      test_case_results[:output].concat( group_results[:output] )
    end

    # No retry group, across the entire file, ever showed real crash evidence, yet this
    # method only runs because the main run was already established as a crash. An
    # all-clean diagnostic must never be allowed to overrule that -- fall back to the
    # same whole-file crash-as-failure construction the :none backtrace setting uses.
    unless any_group_crashed
      @loginator.log(
        "Diagnostic retry for `#{File.basename(executable)}` could not reproduce the crash " \
        "already detected on the main run -- reporting the original crash rather than trusting " \
        "an all-clear diagnostic that contradicts it.",
        Verbosity::ERRORS, LogLabels::CRASH
      )
      return @generator_test_results.create_crash_failure( filename, shell_result, test_cases )
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

  # Re-runs each test case (or, for a parameterized test, each group of parameterized
  # cases -- see `group_test_cases`) individually to determine which one(s) crashed.
  # For crash cases, captures any extra output from the test binary (e.g.
  # assertion messages on stderr) and includes it in the failure report.
  # Returns a modified shell_result with regenerated output.
  def do_simple(filename, executable, shell_result, test_cases, context:)
    # Clean stats tracker
    test_case_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )

    # Reset time
    shell_result[:time] = 0

    # True once some retry group has actually shown crash evidence of its own -- a
    # member with no result line, or (below) a group whose real status contradicts a
    # fully clean set of matches. If this stays false across every group, the whole
    # diagnostic never reproduced or attributed the crash the main run already
    # detected, and none of it can be trusted -- see the fallback after the loop.
    any_group_crashed = false

    # Iterate on test cases, one sub-process run per group (see `group_test_cases`)
    group_test_cases( test_cases ).each do |group|
      # Build the test fixture to run with our test case (or parameterized group) of interest
      command = @tool_executor.build_command_line(
        @configurator.tools_test_fixture_simple_backtrace, [],
        executable,
        unity_filter_arg( group )
      )
      # Things are gonna go boom, so ignore booms to get output
      command[:options][:boom] = false

      crash_result = @tool_executor.exec( command )

      # Sum execution time for each sub-process run
      # Note: Running tests separately increases total execution time
      shell_result[:time] += crash_result[:time].to_f()

      # Buffered separately from test_case_results and only merged in afterward, since
      # the status check below can still discard every match here in favor of a crash
      # attribution, once the whole group has been seen.
      group_results = @RESULTS_COLLECTOR.new( passed:0, failed:0, ignored:0, output:[] )
      crashed = false # Has the actual crash in this group already been attributed?

      # Attribute each group member its own real result line, if Unity printed one
      group.each do |test_case|
        case crash_result[:output]
        # Success test case
        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:PASS\s*$)/
          group_results[:passed]  += 1
          group_results[:output] << $1

        # Ignored test case
        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:IGNORE\s*$)/
          group_results[:ignored] += 1
          group_results[:output] << $1

        when /(^#{Regexp.escape(filename)}:\d+:#{Regexp.escape(test_case[:test])}:FAIL(:.+)?\s*$)/
          group_results[:failed]  += 1
          group_results[:output] << $1

        # No result line for this member -- either it crashed, or it never got to run
        # because an earlier member in this same group crashed.
        else
          group_results[:failed] += 1

          if crashed
            group_results[:output] <<
              "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: " \
              "Test case not run -- an earlier case in this parameterized test group crashed"
          else
            crashed = true
            # Collect any non-result, non-blank lines (e.g. assertion messages on stderr)
            extra = extract_simple_crash_output( crash_result[:output], filename )
            test_output = "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed"
            test_output += " >> #{extra.join(NEWLINE_TOKEN)}" unless extra.empty?
            group_results[:output] << test_output
          end
        end
      end

      # Every member in this group resolved via a matched result line -- but a diagnostic
      # retry running through its own, separately-configured tool (e.g. without the main
      # :test_fixture's sanitizer options) can complete cleanly and print a legitimate-
      # looking PASS even when it isn't a trustworthy stand-in for what actually happened.
      # The same real-status check the main run itself relies on applies here too.
      if !crashed && @helper.test_crash?( filename, executable, crash_result )
        crashed = true
        group_results = @RESULTS_COLLECTOR.new(
          passed: 0, ignored: 0, failed: group.size,
          output: group.map { |test_case|
            "#{filename}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test case crashed" \
            " >> diagnostic retry's own exit status contradicts its reported clean result"
          }
        )
      end

      any_group_crashed ||= crashed

      test_case_results[:passed]  += group_results[:passed]
      test_case_results[:ignored] += group_results[:ignored]
      test_case_results[:failed]  += group_results[:failed]
      test_case_results[:output].concat( group_results[:output] )
    end

    # No retry group, across the entire file, ever showed real crash evidence, yet this
    # method only runs because the main run was already established as a crash. An
    # all-clean diagnostic must never be allowed to overrule that -- fall back to the
    # same whole-file crash-as-failure construction the :none backtrace setting uses.
    unless any_group_crashed
      @loginator.log(
        "Diagnostic retry for `#{File.basename(executable)}` could not reproduce the crash " \
        "already detected on the main run -- reporting the original crash rather than trusting " \
        "an all-clear diagnostic that contradicts it.",
        Verbosity::ERRORS, LogLabels::CRASH
      )
      return @generator_test_results.create_crash_failure( filename, shell_result, test_cases )
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

  # Groups test cases so each parameterized test's cases are isolated together as one
  # sub-process run instead of one run per case. Unity's `-n`/`-f` command-line filter
  # parser treats a comma as a separator between multiple OR'd filter clauses, so an
  # exact filter can never match a parameterized case's runtime name once it has more
  # than one argument (e.g. `name(5, 3, 2)`). Grouping by base name and matching each
  # member's own result line out of the group's single shared sub-run output sidesteps
  # that limitation entirely. Non-parameterized test cases are unaffected: each forms
  # its own single-member group, isolated exactly as before.
  def group_test_cases(test_cases)
    test_cases.group_by { |test_case| test_case[:test].sub(/\(.*\)\z/, '') }.values
  end

  # Builds the Unity command-line filter argument for isolating one group (see
  # `group_test_cases`). A non-parameterized (single-member, no-args) group is isolated
  # with an exact-match filter as before. A parameterized group is isolated with a
  # non-strict prefix filter on its shared base name -- the only reliable way to select
  # such a group, since its members' runtime names contain commas.
  def unity_filter_arg(group)
    test_name = group.first[:test]

    if test_name.include?('(')
      base_name = test_name.sub(/\(.*\)\z/, '')
      %(-f "#{base_name}")
    else
      %(-n "#{test_name}")
    end
  end

  # Builds a terse crash label from gdb output.
  # Rules:
  #   - Named signal explicitly in output → "[SIGNAL] Description"
  #   - Unknown signal (?) or no signal line → description only, no brackets
  #   - Assertion text always preferred over bare signal description
  #   - "Unknown signal" alone is not surfaced — returns '' when nothing useful is found
  # Handles both Linux ("Program received signal") and Windows ("Thread N received signal").
  def format_signal_label(output)
    # Match both Linux ("Program received signal") and Windows ("Thread N received signal")
    m = output.match( /(?:Program|Thread \d+) received signal (\?|\w+), (.+)\./ )

    signal      = m ? m[1] : nil
    description = m ? m[2].strip : nil

    # Linux glibc assertion text — more informative than bare "Aborted"
    # e.g. "src/lib.c:5: func: Assertion `0' failed."
    if (a = output.match( /\S+:\d+: \S+: Assertion `(.+)' failed\./ ))
      description = "Assertion '#{a[1]}' failed"
      signal = nil if signal == '?'  # Don't claim SIGABRT if signal wasn't explicitly named
    end

    # Windows MSVC/MinGW assertion text — appears at end of gdb output
    # e.g. "Assertion failed: 0, file test/file.c, line 24"
    if (a = output.match( /Assertion failed: (.+?), file / ))
      description = "Assertion '#{a[1]}' failed"
      signal = nil if signal == '?'  # Don't claim SIGABRT if signal wasn't explicitly named
    end

    # Nothing useful found in this gdb output
    return '' if description.nil?

    # Unknown signal (?) with no assertion: include Windows exception code if present,
    # otherwise "Unknown signal" alone is not useful — fall back to failed-to-extract
    if signal == '?'
      if (e = output.match( /gdb: unknown target exception (0x[0-9a-fA-F]+)/ ))
        return "Windows exception #{e[1]}"  # No brackets — signal name is unknown
      else
        return ''
      end
    end

    # Named signal: bracketed format. No signal line: description only, no brackets.
    return signal ? "[#{signal}] #{description}" : description
  end

  # Extracts the offending source line from gdb output.
  # Looks for a `<line_num><whitespace><code>` line immediately following the
  # crash location line (`test_case() at filename:line`).
  # Returns nil for assertion crashes (description is already informative)
  # and nil when no source line is available in the gdb output.
  #
  # Handles both Linux (tab separator, LF endings) and Windows
  # (space separator, optional CRLF endings) gdb output formats.
  def extract_source_line(output, test_case, filename)
    # Assertion crashes: description is already informative — no source line needed
    # Linux glibc format: "file:line: func: Assertion `expr' failed."
    return nil if output.match?( /\S+:\d+: \S+: Assertion `.+' failed\./ )
    # Windows MSVC/MinGW format: "Assertion failed: expr, file file, line N"
    return nil if output.match?( /Assertion failed:.+, file / )

    # Find source line immediately following the crash location line.
    # Linux gdb uses TAB; Windows gdb uses spaces — accept either.
    # CRLF line endings on Windows handled via \r?\n.
    m = output.match( /#{Regexp.escape(test_case)}.+#{Regexp.escape(filename)}:\d+\r?\n(\d+)[ \t]+(.+)/ )
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
