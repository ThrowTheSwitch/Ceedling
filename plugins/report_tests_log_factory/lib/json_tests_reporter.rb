# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'tests_reporter'

class JsonTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'tests_report.json' )
  end

  def body(stream:, name:, results:, duration_s:)
    hash = {
      "Name"          => name,
      "BuildDuration" => duration_s,
      "FailedTests"   => write_failures( results[:failures] ),
      "PassedTests"   => write_tests( results[:successes] ),
      "IgnoredTests"  => write_tests( results[:ignores] ),
      "Summary"       => write_statistics( results[:counts] )
    }

    stream << JSON.pretty_generate(hash)
  end

  ### Private

  private

  # Array of hashes relating a source file, test, and test failure
  def write_failures(results)
    failures = tests_in( results ).map do |file, item|
      { "file" => file, "test" => item[:test], "line" => item[:line], "message" => item[:message] }
    end
    return failures.uniq
  end

  # Array of hashes relating a source file and test
  def write_tests(results)
    return tests_in( results ).map { |file, item| { "file" => file, "test" => item[:test] } }
  end

  # Every test in a results category, paired with its source file
  def tests_in(results)
    return results.flat_map { |result| result[:collection].map { |item| [ result[:source][:file], item ] } }
  end

  def write_statistics(counts)
    # Hash of keys:values for statistics
    return {
      "total_tests" => counts[:total],
      "passed" => counts[:passed],
      "ignored" => counts[:ignored],
      "failures" => counts[:failed]
    }
  end

end