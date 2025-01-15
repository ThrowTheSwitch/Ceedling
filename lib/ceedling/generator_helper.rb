# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'


class GeneratorHelper

  constructor :loginator

  def test_crash?(test_filename, executable, shell_result)
    runner = File.basename(executable)

    crash = false

    # Unix Signal 11 ==> SIGSEGV
    # Applies to Unix-like systems including MSYS on Windows
    if (shell_result[:status].termsig == 11)
      @loginator.log( "#{runner} process terminated with SIGSEGV (Unix Signal 11)", Verbosity::DEBUG, LogLabels::CRASH )
      crash = true
    end

    # No test results found in test executable output
    if (shell_result[:output] =~ PATTERNS::TEST_STDOUT_STATISTICS).nil?
      # No debug logging here because we log this condition in the error log handling below
      crash = true
    end

    # Negative lookahead regex that checks all lines in test STDERR output.
    # (?m) enables multiline mode.
    # Matches only a line with a 'segfault' variant that does not begin with the test code filename.
    # Processing STDERR and ignoring lines that look like test case results helps limit false positives.
    segfault_pattern = 'Seg.*fault'
    regex = /\A(?!(?m).*^#{Regexp.escape(test_filename)}.*$).*(?:#{segfault_pattern})/mi
  
    if shell_result[:stderr].match?(regex)
      @loginator.log( "#{runner} STDERR reports segmentation fault", Verbosity::DEBUG, LogLabels::CRASH )
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
  
end
