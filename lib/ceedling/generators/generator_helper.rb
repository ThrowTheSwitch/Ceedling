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

end
