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
    @test_counter = 0
  end
  
  # CppUnit XML header
  def header(stream:, name:, **)
    stream.puts( '<?xml version="1.0" encoding="utf-8" ?>' )
    stream.puts( "<TestRun name=\"#{xml_escape( name )}\">" )
  end

  # CppUnit XML test list contents
  def body(stream:, results:, **)
    @test_counter = 1
    write_category( results[:failures], 'FailedTests', stream ) { |item, filename| write_failure( item, filename, stream ) }
    write_category( results[:successes], 'SuccessfulTests', stream ) { |item, filename| write_test( item, filename, stream ) }
    write_category( results[:ignores], 'IgnoredTests', stream ) { |item, filename| write_test( item, filename, stream ) }
    write_statistics( results[:counts], stream )
  end

  # CppUnit XML footer
  def footer(stream:, **)
    stream.puts( "</TestRun>" )
  end

  ### Private

  private

  # Yields each test in a category to the block that writes it. An empty category is a
  # self-closing element. Test ids run on across categories.
  def write_category(results, tag, stream)
    return stream.puts( "  <#{tag}/>" ) if results.empty?

    stream.puts( "  <#{tag}>" )
    results.each do |result|
      filename = xml_escape( result[:source][:file] )
      result[:collection].each { |item| yield( item, filename ) }
    end
    stream.puts( "  </#{tag}>" )
  end

  def write_failure(item, filename, stream)
    stream.puts "    <Test id=\"#{@test_counter}\">"
    stream.puts "      <Name>#{filename}::#{xml_escape( item[:test] )}</Name>"
    stream.puts "      <FailureType>Assertion</FailureType>"
    stream.puts "      <Location>"
    stream.puts "        <File>#{filename}</File>"
    stream.puts "        <Line>#{item[:line]}</Line>"
    stream.puts "      </Location>"
    stream.puts "      <Message>#{xml_escape( item[:message] )}</Message>"
    stream.puts "    </Test>"
    @test_counter += 1
  end

  def write_test(item, filename, stream)
    stream.puts( "    <Test id=\"#{@test_counter}\">" )
    stream.puts( "      <Name>#{filename}::#{xml_escape( item[:test] )}</Name>" )
    stream.puts( "    </Test>" )
    @test_counter += 1
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
