# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'


class GeneratorHelper

  constructor :loginator

  # Every rule is checked, rather than stopping at the first, so each one that applies
  # leaves its own debug log line
  def test_crash?(test_filename, executable, shell_result)
    runner      = File.basename(executable)
    stats_match = shell_result[:output].match( PATTERNS::TEST_STDOUT_STATISTICS )

    return [
      signal_death?( runner, shell_result[:status] ),
      # Logged with the crash report itself, not here
      stats_match.nil?,
      clean_summary_contradicted?( runner, shell_result[:status], stats_match ),
      bare_segfault?( runner, test_filename, shell_result[:stderr] )
    ].any?
  end

  def log_test_results_crash(executable, shell_result, backtrace, gdb_unavailable: false)
    runner = File.basename(executable)

    notice  = "Test executable `#{runner}` seems to have crashed -- likely terminating early due to a bad code reference.\n"
    notice += crash_output_notice( shell_result[:output] )
    notice += "> Causes can include: bad memory access, stack overflow, heap error, or bad branch in source or test code.\n"
    notice += backtrace_advice( backtrace, gdb_unavailable )

    @loginator.log( notice, Verbosity::ERRORS, LogLabels::CRASH )
  end

  # A plugin's explanation names the cause, so no generic guidance follows it
  def log_explained_crash(executable, explanation)
    notice  = "Test executable `#{File.basename( executable )}` #{explanation[:heading] || 'crashed'}.\n"
    notice += ([explanation[:cause]] + explanation[:details]).map { |line| "> #{line}\n" }.join

    @loginator.log( notice, Verbosity::ERRORS, LogLabels::CRASH )
  end

  # A "redeclaration"/"redefinition"/"conflicting types"/"previous definition" family
  # of compiler errors mentioning a header this test also mocks or Partializes is a
  # strong signal that the real header's own content reached this compile a second,
  # unmocked way -- substitution only ever replaces what a test's own #include
  # directives name directly, so a module reaching the same real header through some
  # other, unrelated #include chain slips past it entirely, and the genuine and
  # substituted copies of the same declarations collide in the one compiled
  # translation unit. Different compilers word this differently -- gcc's own
  # "conflicting types for" and clang's "redefinition of"/"previous definition is
  # here" are both real, observed wordings for the same underlying constraint
  # violation, not a hypothetical spread to guard against.
  #
  # `mocked_headers` maps a real header's own basename to its real, resolved path --
  # exactly the substitution knowledge a test's own mocks/Partials configuration
  # already carries, cross-referenced here against whichever file paths the compiler's
  # own error text happens to mention.
  def explain_possible_mock_partial_collision(output:, mocked_headers:)
    return nil if output.nil?
    return nil unless output.match?(/redeclaration of|redefinition of|conflicting types|previous definition/i)

    mentioned = output.scan( /([^\s"]+\.h):\d+:\d+/ ).flatten.uniq

    culprit = mocked_headers.find do |basename, real_path|
      mentioned.any? { |m| File.basename( m ) == basename && File.expand_path( m ) == File.expand_path( real_path ) }
    end
    return nil if culprit.nil?

    return collision_notice( *culprit )
  end

  ### Private ###

  private

  # Any signal death is unconditionally a crash, whatever text made it out beforehand. A
  # sanitizer that aborts raises SIGABRT, not SIGSEGV, and a process a signal killed is not
  # to be trusted whichever signal it was. Native Windows Ruby never reports `signaled?`, so
  # the check is inert there; the statistics and stderr checks carry Windows detection.
  def signal_death?(runner, status)
    return false unless status&.signaled?

    @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) { "#{runner} process terminated by signal #{status.termsig}" }
    return true
  end

  # A clean summary (0 failures) is not trustworthy if the process still exited nonzero
  # afterward, e.g. a leak check at exit after every test case printed. A nonzero exit
  # consistent with Unity's reported failures (its exit code is one per failed test case)
  # is an ordinary failing run, not a crash.
  def clean_summary_contradicted?(runner, status, stats_match)
    return false if stats_match.nil? || status.nil? || status.success? || status.signaled?
    return false unless stats_match[2].to_i == 0

    @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) do
      "#{runner} reported a clean summary but exited with real status #{status.exitstatus}"
    end
    return true
  end

  # A segfault line not starting with the test filename is an OS crash. A line starting
  # with it is a Unity test-case result. Each line is checked on its own, so an attributed
  # line beside a bare one still finds the bare one.
  def bare_segfault?(runner, test_filename, stderr)
    bare = stderr.each_line.any? { |line| line.match?( /Seg.*fault/i ) && !line.start_with?( test_filename ) }
    return false unless bare

    @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) { "#{runner} STDERR reports segmentation fault" }
    return true
  end

  # Mirrors the style of the generic tool_executor failure output
  def crash_output_notice(output)
    return "> Produced no output (including no final test result counts).\n" if output.nil? || output.strip.empty?
    return "> Produced some output but contains no final test result counts.\n" if (output =~ PATTERNS::TEST_STDOUT_STATISTICS).nil?

    return ''
  end

  # No :gdb advice where :gdb can't be used
  def backtrace_advice(backtrace, gdb_unavailable)
    return "> Consider configuring :project ↳ :use_backtrace to help find the cause (see documentation).\n" if backtrace == :none
    return '' unless backtrace == :simple && !gdb_unavailable

    return "> Consider configuring :project ↳ :use_backtrace to use the :gdb option to find the cause (see documentation).\n"
  end


  def collision_notice(basename, real_path)
    notice  = "This looks like '#{basename}' is mocked or Partialized for this test, but its " \
              "real content ('#{real_path}') is also reaching compilation through a second " \
              "unmocked #include chain.\n"
    notice += "> The cause is most likely a transitive #include chain through an unrelated " \
              "header brought about by C convention quirks in search paths and #include guards.\n"
    notice += "> Consider investigating the #include chain and modifying your source or " \
              "Partializing/mocking the problematic header (without necessarily using it) to " \
              "break the transitive #include chain.\n"

    return notice
  end

end
