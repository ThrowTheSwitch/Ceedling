# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'

class JunitTestsReporter < TestsReporter

  # :file_line_anchor writes a located test's file attribute as path#line, a form some
  # tools follow to the line
  def setup()
    super( default_filename: 'junit_tests_report.xml' )
    @file_line_anchor = fetch_config_value( :file_line_anchor ) == true
  end

  # Each results category and the outcome its tests carry in a suite
  CATEGORIES = { successes: :success, failures: :failed, ignores: :ignored }.freeze

  def header(stream:, name:, results:, **)
    stream.puts( '<?xml version="1.0" encoding="utf-8" ?>' )
    stream.puts(
      '<testsuites name="%s" '     % xml_escape( name ) +
                  'tests="%d" '    % results[:counts][:total] +
                  'failures="%d" ' % results[:counts][:failed] +
                  'time="%.3f">'   % results[:total_time]
    )
  end

  def body(stream:, results:, **)
    reorganize_results( results ).each do |suite|
      write_suite( suite, stream )
    end
  end

  def footer(stream:, **)
    stream.puts( '</testsuites>' )
  end

  ### Private

  private

  # Regroups results by test file, the unit a JUnit testsuite describes, instead of by
  # outcome. Every test carries its outcome, and a suite's counts come from its tests.
  # Results are read, never altered, since every configured reporter shares them.
  def reorganize_results(results)
    suites = Hash.new { |hash, name| hash[name] = { name: name, collection: [], time: 0, stdout: [] } }

    CATEGORIES.each do |category, outcome|
      results[category].each { |result| add_tests( suites, result, results[:times], outcome ) }
    end

    results[:stdout].each { |result| add_stdout( suites, result ) }

    return suites.values
  end

  def add_tests(suites, result, times, outcome)
    source = result[:source][:file]
    suite  = suites[suite_name( source )]

    # Skip nil and empty entries a results file may carry
    tests = result[:collection].reject { |test| test.nil? or test.empty? }

    suite[:collection] += tests.map { |test| test.merge( result: outcome, source: source ) }
    suite[:time] = times[source]
  end

  def add_stdout(suites, result)
    suites[suite_name( result[:source][:file] )][:stdout] += result[:collection]
  end

  # A suite is named for its test file without the file's extension
  def suite_name(source)
    return source.delete_suffix( File.extname( source ) )
  end

  def write_suite(suite, stream)
    stream.puts( suite_tag( suite ) )
    suite[:collection].each { |test| write_test( test, stream ) }
    write_stdout( suite[:stdout], stream )
    stream.puts( '  </testsuite>' )
  end

  # Ceedling has no notion of a test error distinct from a failure, so errors is always 0
  def suite_tag(suite)
    tests   = suite[:collection]
    failed  = tests.count { |test| test[:result] == :failed }
    ignored = tests.count { |test| test[:result] == :ignored }

    return '  <testsuite name="%s" tests="%d" failures="%d" skipped="%d" errors="0" time="%.3f">' %
      [ xml_escape( suite[:name] ), tests.length, failed, ignored, suite[:time] ]
  end

  def write_stdout(lines, stream)
    return if lines.empty?

    stream.puts( '    <system-out>' )
    lines.each { |line| stream.puts( xml_escape( line ) ) }
    stream.puts( '    </system-out>' )
  end

  # A passing test is an empty element. Any other test holds an element for its outcome.
  def write_test(test, stream)
    opening = "    <testcase #{attributes( testcase_attributes( test ) )}"
    outcome = outcome_element( test )

    return stream.puts( opening + '/>' ) if outcome.nil?

    stream.puts( opening + '>' )
    stream.puts( '      ' + outcome )
    stream.puts( '    </testcase>' )
  end

  # A test's class is its suite, path kept, so same-named test files in different folders,
  # and their same-named test cases, stay distinct where CI tools group results by class.
  # A test carries the line Unity reported for it, when its results name one.
  def testcase_attributes(test)
    attributes = { name: test[:test], classname: suite_name( test[:source] ), file: test_file( test ) }
    attributes[:line] = test[:line] unless test[:line].nil?
    attributes[:time] = format( '%.3f', test[:unity_test_time] )
    return attributes
  end

  def test_file(test)
    return test[:source] unless @file_line_anchor && test[:line]

    return "#{test[:source]}##{test[:line]}"
  end

  # A failure's message starts with its file and line in the form compilers use, which
  # readers and tools recognize
  def located_message(test)
    return test[:message] if test[:line].nil?

    return "#{test[:source]}:#{test[:line]}: #{test[:message]}"
  end

  # Each attribute's value escaped, in the order given
  def attributes(pairs)
    return pairs.map { |key, value| %(#{key}="#{xml_escape( value )}") }.join( ' ' )
  end

  def outcome_element(test)
    case test[:result]
    when :failed
      return '<failure />' if test[:message].to_s.empty?
      return '<failure message="%s" />' % xml_escape( located_message( test ) )
    when :ignored
      return '<skipped />'
    end
  end
end
