# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'

class CppunitTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'cppunit_tests_report.xml' )
  end

  # CppUnit XML header
  def header(stream:, name:, **)
    stream.puts( '<?xml version="1.0" encoding="utf-8" ?>' )
    stream.puts( "<TestRun name=\"#{xml_escape( name )}\">" )
  end

  # CppUnit XML test list contents. Test ids run on across categories.
  def body(stream:, results:, **)
    ids = (1..).each
    write_category( results[:failures], 'FailedTests', stream ) { |item, file| write_failure( item, file, ids.next, stream ) }
    write_category( results[:successes], 'SuccessfulTests', stream ) { |item, file| write_test( item, file, ids.next, stream ) }
    write_category( results[:ignores], 'IgnoredTests', stream ) { |item, file| write_test( item, file, ids.next, stream ) }
    write_statistics( results[:counts], stream )
  end

  # CppUnit XML footer
  def footer(stream:, **)
    stream.puts( "</TestRun>" )
  end

  ### Private

  private

  # Yields each test in a category, with its escaped filename, to the block that writes it.
  # An empty category is a self-closing element.
  def write_category(results, tag, stream)
    return stream.puts( "  <#{tag}/>" ) if results.empty?

    stream.puts( "  <#{tag}>" )
    results.each do |result|
      file = xml_escape( result[:source][:file] )
      result[:collection].each { |item| yield( item, file ) }
    end
    stream.puts( "  </#{tag}>" )
  end

  # A failure is a test element that also holds where and why the test failed
  def write_failure(item, file, id, stream)
    write_test( item, file, id, stream ) do
      stream.puts( "      <FailureType>Assertion</FailureType>" )
      stream.puts( "      <Location>" )
      stream.puts( "        <File>#{file}</File>" )
      stream.puts( "        <Line>#{item[:line]}</Line>" )
      stream.puts( "      </Location>" )
      stream.puts( "      <Message>#{xml_escape( item[:message] )}</Message>" )
    end
  end

  def write_test(item, file, id, stream)
    stream.puts( "    <Test id=\"#{id}\">" )
    stream.puts( "      <Name>#{file}::#{xml_escape( item[:test] )}</Name>" )
    yield if block_given?
    stream.puts( "    </Test>" )
  end

  def write_statistics(counts, stream)
    stream.puts( "  <Statistics>" )
    stream.puts( "    <Tests>#{counts[:total]}</Tests>" )
    stream.puts( "    <Ignores>#{counts[:ignored]}</Ignores>" )
    stream.puts( "    <FailuresTotal>#{counts[:failed]}</FailuresTotal>" )
    stream.puts( "    <Errors>0</Errors>" )
    stream.puts( "    <Failures>#{counts[:failed]}</Failures>" )
    stream.puts( "  </Statistics>" )
  end

end
