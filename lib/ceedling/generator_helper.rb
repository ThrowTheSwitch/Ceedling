# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'


class GeneratorHelper

  constructor :loginator

  def test_crash?(shell_result)
    return true if (shell_result[:output] =~ /\s*Segmentation\sfault.*/i)

    # Unix Signal 11 ==> SIGSEGV
    # Applies to Unix-like systems including MSYS on Windows
    return true if (shell_result[:status].termsig == 11)

    # No test results found in test executable output
    return true if (shell_result[:output] =~ TEST_STDOUT_STATISTICS_PATTERN).nil?

    return false
  end

  def log_test_results_crash(test_name, executable, shell_result)
    runner = File.basename(executable)

    notice = "Test executable `#{runner}` seems to have crashed"
    @loginator.log( notice, Verbosity::ERRORS, LogLabels::CRASH )

    log = false

    # Check for empty output
    if (shell_result[:output].nil? or shell_result[:output].strip.empty?)
      # Mirror style of generic tool_executor failure output
      notice = "Test executable `#{runner}` failed.\n" +
               "> Produced no output\n"

      log = true

    # Check for no test results
    elsif ((shell_result[:output] =~ TEST_STDOUT_STATISTICS_PATTERN).nil?)
      # Mirror style of generic tool_executor failure output
      notice = "Test executable `#{runner}` failed.\n" +
               "> Output contains no test result counts\n"

      log = true
    end
    
    if (log)
      if (shell_result[:exit_code] != nil)
        notice += "> And terminated with exit code: [#{shell_result[:exit_code]}] (failed test case count).\n" 
      end

      notice += "> Causes can include a bad memory access, stack overflow, heap error, or bad branch in source or test code.\n"

      @loginator.log( '', Verbosity::OBNOXIOUS )
      @loginator.log( notice, Verbosity::OBNOXIOUS, LogLabels::ERROR )
      @loginator.log( '', Verbosity::OBNOXIOUS )
    end
  end
  
end
