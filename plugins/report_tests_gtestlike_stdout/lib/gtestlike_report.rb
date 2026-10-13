# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Translates Ceedling's aggregated test results into a GoogleTest console report.
#
# A Ceedling test file maps to a GTest test case and each of its Unity test cases
# to a GTest test. The report reads results without altering them, since every
# reporting plugin receives the same results.
class GtestlikeReport

  Test    = Struct.new( :file, :name, :line, :message, :status, keyword_init: true )
  Section = Struct.new( :file, :tests, :duration_ms, keyword_init: true )

  # Matches Unity's comparison message, e.g. "Expected 1 Was 2."
  EXPECTATION = /Expected\s+(.*)\s+Was\s+([^\.]*)\./

  # Splits a failure message into GTest's actual and expected values. Any message
  # that is not a Unity comparison reads as a failed boolean assertion.
  def self.expectation(message)
    match = message.to_s.match( EXPECTATION )

    return match.nil? ? ['FALSE', 'TRUE'] : [match[2], match[1]]
  end

  attr_reader :sections, :failures

  def initialize(results, context:)
    @context  = context
    @failures = tests_from( results[:failures], :failed )
    @sections = build_sections( results[:times], tests_from( results[:successes], :ok ) + @failures )
  end

  def total = @sections.sum { |section| section.tests.length }

  def passed = total - @failures.length

  def suite_count = @sections.length

  def render
    lines = ['']
    lines << "Running testing tasks: #{@context.to_s.upcase}" if @context != TEST_SYM
    lines << "[==========] Running #{total} tests from #{suite_count} test cases."
    lines << '[----------] Global test environment set-up.'
    @sections.each { |section| lines.concat( section_lines( section ) ) }
    lines << ''
    lines.concat( total > 0 ? summary_lines : ['', 'No tests executed.'] )

    return lines.join( "\n" ) + "\n"
  end

  ### Private ###

  private

  def tests_from(entries, status)
    return entries.flat_map do |entry|
      entry[:collection].map do |item|
        Test.new( file: entry[:source][:file], name: item[:test], line: item[:line], message: item[:message].to_s, status: status )
      end
    end
  end

  # Sections keep each file's first appearance in order, with its tests in arrival order.
  # Durations arrive in seconds per file and print as whole milliseconds.
  def build_sections(times, tests)
    return tests.group_by( &:file ).map do |file, file_tests|
      Section.new( file: file, tests: file_tests, duration_ms: (times.fetch( file, 0 ) * 1000.0).round )
    end
  end

  def section_lines(section)
    heading = "#{section.tests.length} tests from #{section.file}"
    lines = ["[----------] #{heading}"]

    section.tests.each do |test|
      lines << "[ RUN      ] #{test.file}.#{test.name}"
      lines.concat( failure_lines( test ) ) if test.status == :failed
      lines << "#{status_tag( test )} #{test.file}.#{test.name} (0 ms)"
    end

    return lines << "[----------] #{heading} (#{section.duration_ms} ms total)"
  end

  # An empty failure message runs straight into the Actual line, as the report has always printed it
  def failure_lines(test)
    actual, expected = self.class.expectation( test.message )
    location = "#{test.file}(#{test.line}):"

    if test.message.empty?
      return ["#{location} fail:  Actual:   FALSE", ' Expected: TRUE']
    end

    return ["#{location} error: #{test.message}", " Actual:   #{actual}", " Expected: #{expected}"]
  end

  def status_tag(test) = test.status == :failed ? '[  FAILED  ]' : '[       OK ]'

  def summary_lines
    lines = [
      '[----------] Global test environment tear-down.',
      "[==========] #{total} tests from #{suite_count} test cases ran.",
      "[  PASSED  ] #{passed} tests."
    ]

    if @failures.empty?
      lines << '[  FAILED  ] 0 tests.'
    else
      lines << "[  FAILED  ] #{@failures.length} tests, listed below:"
      lines.concat( @failures.map { |test| "[  FAILED  ] #{test.file}.#{test.name}" } )
    end

    return lines.push( '', " #{@failures.length} FAILED TESTS" )
  end

end
