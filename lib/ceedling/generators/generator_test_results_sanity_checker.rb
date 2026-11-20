# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for ext() method
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/reportinator'


class GeneratorTestResultsSanityChecker

  # What an interrupted test execution can come from
  SANITY_CHECK_CAUSES = [
    'Your test + source dereferenced a null pointer.',
    'Your test + source indexed past the end of a buffer.',
    'Your test + source committed a memory access violation.',
    'Your test fixture produced an exit code of 0 despite execution ending prematurely.'
  ].freeze

  constructor :configurator, :loginator
  
  def verify(results, unity_exit_code)
  
    # do no sanity checking if it's disabled
    return if (@configurator.sanity_checks == TestResultsSanityChecks::NONE)
    raise CeedlingException.new( "Test results nil or empty" ) if results.nil? || results.empty?

    ceedling_ignores_count   = results[:ignores].size 
    ceedling_failures_count  = results[:failures].size
    ceedling_tests_summation = (ceedling_ignores_count + ceedling_failures_count + results[:successes].size)

    # Exit code handling is not a sanity check that can always be performed because 
    # command line simulators may or may not pass through Unity's exit code
    if (@configurator.sanity_checks >= TestResultsSanityChecks::THOROUGH)
      # many platforms limit exit codes to a maximum of 255
      if ((ceedling_failures_count != unity_exit_code) and (unity_exit_code < 255))
        sanity_check_warning(results[:source][:file], "Unity's exit code (#{unity_exit_code}) does not match Ceedling's summation of failed test cases (#{ceedling_failures_count}).")
      end
      
      if ((ceedling_failures_count < 255) and (unity_exit_code == 255))
        sanity_check_warning(results[:source][:file], "Ceedling's summation of failed test cases (#{ceedling_failures_count}) is less than Unity's exit code (255 or more).")
      end
    end
    
    if (ceedling_ignores_count != results[:counts][:ignored])
      sanity_check_warning(results[:source][:file], "Unity's final ignore count (#{results[:counts][:ignored]}) does not match Ceedling's summation of ignored test cases (#{ceedling_ignores_count}).")
    end
    
    if (ceedling_failures_count != results[:counts][:failed])
      sanity_check_warning(results[:source][:file], "Unity's final fail count (#{results[:counts][:failed]}) does not match Ceedling's summation of failed test cases (#{ceedling_failures_count}).")
    end

    if (ceedling_tests_summation != results[:counts][:total])
      sanity_check_warning(results[:source][:file], "Unity's final test count (#{results[:counts][:total]}) does not match Ceedling's summation of all test cases (#{ceedling_tests_summation}).")
    end
    
  end

  private
  
  def sanity_check_warning(file, message)
    unless defined?(CEEDLING_IGNORE_SANITY_CHECK)
      notice = Reportinator.generate_guidance(
        lead:     "Internal sanity check for test fixture '#{file.ext(@configurator.extension_executable.primary)}' finds that #{message}",
        causes:   SANITY_CHECK_CAUSES,
        notes:    ['Sanity check failures of test results are usually a symptom of interrupted test execution.'],
        headings: { causes: 'POSSIBLE CAUSES' }
      )
      raise CeedlingException.new( notice )
    end
  end

end
