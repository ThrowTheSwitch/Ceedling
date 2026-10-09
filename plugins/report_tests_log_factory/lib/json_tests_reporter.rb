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
      "FailedTests"   => failure_entries( results[:failures] ),
      "PassedTests"   => test_entries( results[:successes] ),
      "IgnoredTests"  => test_entries( results[:ignores] ),
      "Summary"       => statistics( results[:counts] )
    }

    stream << JSON.pretty_generate(hash)
  end

  ### Private

  private

  # Each failure relates a source file, test, line, and message
  def failure_entries(results)
    entries = tests_in( results ).map do |file, item|
      { "file" => file, "test" => item[:test], "line" => item[:line], "message" => item[:message] }
    end
    return entries.uniq
  end

  # Each entry relates a source file and test
  def test_entries(results)
    return tests_in( results ).map { |file, item| { "file" => file, "test" => item[:test] } }
  end

  # Every test in a results category, paired with its source file
  def tests_in(results)
    return results.flat_map { |result| result[:collection].map { |item| [ result[:source][:file], item ] } }
  end

  def statistics(counts)
    return {
      "total_tests" => counts[:total],
      "passed"      => counts[:passed],
      "ignored"     => counts[:ignored],
      "failures"    => counts[:failed]
    }
  end

end
