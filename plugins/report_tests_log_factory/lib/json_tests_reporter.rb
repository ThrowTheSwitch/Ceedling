# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'tests_reporter'

class JsonTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'tests_report.json' )
  end

  def body(results:, stream:)
    hash = {
      "FailedTests"  => write_failures( results[:failures] ),
      "PassedTests"  => write_tests( results[:successes] ),
      "IgnoredTests" => write_tests( results[:ignores] ),
      "Summary"      => write_statistics( results[:counts] )
    }
    
    stream << JSON.pretty_generate(hash)
  end

  ### Private

  private

  def write_failures(results)
    # Array of hashes relating a source file, test, and test failure
    failures = []
    results.each do |result|
      result[:collection].each do |item|
        failures << {
          "file" => result[:source][:file],
          "test" => item[:test],
          "line" => item[:line],
          "message" => item[:message]
        }
      end
    end
    return failures.uniq
  end

  def write_tests(results)
    # Array of hashes relating a source file and test
    successes = []
    results.each do |result|
      result[:collection].each do |item|
        successes << { 
          "file" => result[:source][:file],
          "test" => item[:test]
        }
      end
    end
    return successes
  end

  def write_statistics(counts)
    # Hash of keys:values for statistics
    return {
      "total_tests" => counts[:total],
      "passed" => (counts[:total] - counts[:ignored] - counts[:failed]),
      "ignored" => counts[:ignored],
      "failures" => counts[:failed]
    }
  end

end