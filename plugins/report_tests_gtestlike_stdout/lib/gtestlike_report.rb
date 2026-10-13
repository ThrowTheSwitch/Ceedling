# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Translates Ceedling's aggregated test results into a GoogleTest console report.
#
# A Ceedling test file maps to a GTest test suite and each of its Unity test cases
# to a GTest test. Line formats follow GoogleTest's own console printer. The report
# reads results without altering them, since every reporting plugin receives the
# same results.
#
# A Unity ignore is decided at runtime, as GoogleTest's GTEST_SKIP() is, so an
# ignored test can report as skipped. Left out instead, it is neither listed nor
# counted, and a file of only ignored tests has no section.
class GtestlikeReport

  # GoogleTest names a test by its suite and test name joined with a period
  Test = Struct.new( :file, :name, :line, :message, :status, keyword_init: true ) do
    def full_name = "#{file}.#{name}"
  end

  Section = Struct.new( :file, :tests, :duration_ms, keyword_init: true )

  # Matches Unity's comparison message, e.g. "Expected 1 Was 2."
  EXPECTATION = /Expected\s+(.*)\s+Was\s+([^\.]*)\./

  # Splits a failure message into GTest's actual and expected values. Any message
  # that is not a Unity comparison reads as a failed boolean assertion.
  def self.expectation(message)
    match = message.to_s.match( EXPECTATION )

    return match.nil? ? ['FALSE', 'TRUE'] : [match[2], match[1]]
  end

  # GoogleTest's countable noun: singular for exactly one, plural otherwise
  def self.count(n, singular, plural = "#{singular}s") = "#{n} #{n == 1 ? singular : plural}"

  STATUS_TAGS = { ok: '[       OK ]', failed: '[  FAILED  ]', skipped: '[  SKIPPED ]' }.freeze

  attr_reader :sections, :failures, :skipped

  # Failures and skips are listed in suite order, as GoogleTest's summary walks its suites
  def initialize(results, context:, ignored_as_skipped: true)
    @context  = context
    @sections = build_sections( results[:times], gather( results, ignored_as_skipped ) )
    @failures, @skipped = %i[failed skipped].map { |status| all_tests.select { |test| test.status == status } }
    @total_ms = to_ms( results.fetch( :total_time, 0 ) )
  end

  def total = all_tests.length

  def passed = total - @failures.length - @skipped.length

  def suite_count = @sections.length

  def render
    lines = ['']
    lines << "Running testing tasks: #{@context.to_s.upcase}" if @context != TEST_SYM
    lines << "[==========] Running #{tests( total )} from #{suites}."
    lines << '[----------] Global test environment set-up.'
    @sections.each { |section| lines.concat( section_lines( section ) ) }
    lines.concat( total > 0 ? summary_lines : ['', 'No tests executed.'] )

    return lines.join( "\n" ) + "\n"
  end

  ### Private ###

  private

  def tests(n) = self.class.count( n, 'test' )

  def suites = self.class.count( suite_count, 'test suite' )

  def to_ms(seconds) = (seconds * 1000.0).round

  def all_tests = @sections.flat_map( &:tests )

  def gather(results, ignored_as_skipped)
    tests = tests_from( results[:successes], :ok ) + tests_from( results[:failures], :failed )

    return ignored_as_skipped ? tests + tests_from( results[:ignores], :skipped ) : tests
  end

  def tests_from(entries, status)
    return entries.flat_map do |entry|
      entry[:collection].map do |item|
        Test.new( file: entry[:source][:file], name: item[:test], line: item[:line], message: item[:message].to_s, status: status )
      end
    end
  end

  # Sections keep each file's first appearance in order. A file's tests arrive grouped
  # by outcome, so each section sorts them into source order by line. Arrival order
  # breaks ties. Durations arrive in seconds per file.
  def build_sections(times, tests)
    return tests.group_by( &:file ).map do |file, file_tests|
      in_order = file_tests.each_with_index.sort_by { |test, i| [test.line.to_i, i] }.map( &:first )

      Section.new( file: file, tests: in_order, duration_ms: to_ms( times.fetch( file, 0 ) ) )
    end
  end

  # A suite closes with its total time and a blank line, as GoogleTest prints it
  def section_lines(section)
    heading = "#{tests( section.tests.length )} from #{section.file}"
    lines = ["[----------] #{heading}"]

    section.tests.each { |test| lines.concat( test_lines( test ) ) }

    return lines.push( "[----------] #{heading} (#{section.duration_ms} ms total)", '' )
  end

  def test_lines(test)
    lines = ["[ RUN      ] #{test.full_name}"]
    lines.concat( failure_lines( test ) ) if test.status == :failed
    lines.concat( skipped_lines( test ) ) if test.status == :skipped

    return lines << "#{STATUS_TAGS[test.status]} #{test.full_name} (0 ms)"
  end

  # MSVC-style file(line) locations are what IDEs turn into links
  def failure_lines(test)
    location = "#{test.file}(#{test.line}):"
    actual, expected = self.class.expectation( test.message )
    lead = test.message.empty? ? "#{location} fail:" : "#{location} error: #{test.message}"

    return [lead, " Actual:   #{actual}", " Expected: #{expected}"]
  end

  # GoogleTest prints a skip's location, any message, and a blank line before its result
  def skipped_lines(test)
    lines = ["#{test.file}(#{test.line}): Skipped"]
    lines << test.message unless test.message.empty?

    return lines << ''
  end

  # GoogleTest summarizes passed, then skipped, then failed tests, listing skips and
  # failures only when there are any
  def summary_lines
    lines = [
      '[----------] Global test environment tear-down',
      "[==========] #{tests( total )} from #{suites} ran. (#{@total_ms} ms total)",
      "[  PASSED  ] #{tests( passed )}."
    ]
    lines.concat( listing( :skipped, @skipped ) ) unless @skipped.empty?

    return @failures.empty? ? lines : lines + failure_summary_lines
  end

  def listing(status, list)
    tag = STATUS_TAGS[status]

    return ["#{tag} #{tests( list.length )}, listed below:", *list.map { |test| "#{tag} #{test.full_name}" }]
  end

  # The trailer's count is right-aligned to two places, as GoogleTest's printf("%2d") does
  def failure_summary_lines
    count = @failures.length

    return listing( :failed, @failures ).push( '', format( '%2d FAILED %s', count, count == 1 ? 'TEST' : 'TESTS' ) )
  end

end
