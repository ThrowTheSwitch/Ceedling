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

  def test_crash?(test_filename, executable, shell_result)
    runner = File.basename(executable)

    crash = false

    # Any signal death is unconditionally a crash, whatever text made it out beforehand.
    # Broadened from a SIGSEGV(11)-only check: a sanitizer's halt_on_error (UBSan, ASan)
    # raises SIGABRT, not SIGSEGV, and there's no reason to trust a process that a
    # signal actually killed regardless of which one. Applies to Unix-like systems
    # including MSYS on Windows -- native (non-MSYS) Windows Ruby never reports
    # `signaled?` true at all, so this check is inert there rather than wrong; the
    # stats-footer and stderr checks below already carry Windows crash detection.
    if shell_result[:status] && shell_result[:status].signaled?
      @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) do
        "#{runner} process terminated by signal #{shell_result[:status].termsig}"
      end
      crash = true
    end

    # No test results found in test executable output
    stats_match = shell_result[:output].match( PATTERNS::TEST_STDOUT_STATISTICS )
    if stats_match.nil?
      # No debug logging here because we log this condition in the error log handling below
      crash = true
    end

    # A clean summary (0 failures) is not trustworthy if the real process still exited
    # nonzero afterward -- e.g. LeakSanitizer detecting a leak during teardown, after
    # every test case already printed and Unity's own summary already looked clean.
    # A nonzero exit consistent with Unity's own reported failures (its exit code
    # convention is one per failed test case) is an ordinary failing run, not a crash.
    if stats_match && shell_result[:status] && !shell_result[:status].success? &&
       !shell_result[:status].signaled? && stats_match[2].to_i == 0
      @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) do
        "#{runner} reported a clean summary but exited with real status #{shell_result[:status].exitstatus}"
      end
      crash = true
    end

    # Scan STDERR line by line for a segfault variant that is not attributed to the test file.
    # A line starting with test_filename is a Unity-reported test-case result, not an OS crash.
    # Checking each line individually avoids false negatives when attributed and bare segfault
    # lines coexist in the same stderr output.
    segfault_pattern = /Seg.*fault/i
    bare_segfault = shell_result[:stderr].each_line.any? do |line|
      line.match?(segfault_pattern) && !line.start_with?(test_filename)
    end

    if bare_segfault
      @loginator.lazy( Verbosity::DEBUG, LogLabels::CRASH ) do
        "#{runner} STDERR reports segmentation fault"
      end
      crash = true
    end

    return crash
  end

  def log_test_results_crash(executable, shell_result, backtrace)
    runner = File.basename(executable)

    notice = "Test executable `#{runner}` seems to have crashed -- likely terminating early due to a bad code reference.\n"

    # Check for empty output
    if (shell_result[:output].nil? or shell_result[:output].strip.empty?)
      # Mirror style of generic tool_executor failure output
      notice += "> Produced no output (including no final test result counts).\n"

    # Check for no test results
    elsif ((shell_result[:output] =~ PATTERNS::TEST_STDOUT_STATISTICS).nil?)
      # Mirror style of generic tool_executor failure output
      notice += "> Produced some output but contains no final test result counts.\n"
    end
    
    notice += "> Causes can include: bad memory access, stack overflow, heap error, or bad branch in source or test code.\n"

    # Incorporate knowledge of the backtrace setting into a recommendation
    case backtrace
    when :simple
      notice += "> Consider configuring :project ↳ :use_backtrace to use the :gdb option to find the cause (see documentation).\n"
    when :none
      notice += "> Consider configuring :project ↳ :use_backtrace to help find the cause (see documentation).\n"
    end

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
    return nil unless output =~ /redeclaration of|redefinition of|conflicting types|previous definition/i

    mentioned = output.scan( /([^\s"]+\.h):\d+:\d+/ ).flatten.uniq

    culprit = mocked_headers.find do |basename, real_path|
      mentioned.any? { |m| File.basename( m ) == basename && File.expand_path( m ) == File.expand_path( real_path ) }
    end
    return nil if culprit.nil?

    basename, real_path = culprit

    notice  = "This looks like '#{basename}' is mocked or Partialized for this test, but its " \
              "real content ('#{real_path}') is also reaching compilation through a second " \
              "unmocked #include chain.\n"
    notice += "> The cause is most likely a transitive #include chain through an unrelated " \
              "header brought about by C convention quirks in search paths and #include guards.\n"
    notice += "> Consider investigating the #include chain and modifying your source or " \
              "Partializing/mocking the problematic header (without necessarily using it) to " \
              "break the transitive #include chain.\n"

    notice
  end

end
