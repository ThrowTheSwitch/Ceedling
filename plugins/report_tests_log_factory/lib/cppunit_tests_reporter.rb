# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'

class CppunitTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'cppunit_tests_report.xml' )
    @test_counter = 0
  end
  
  # CppUnit XML header
  def header(results:, stream:)
    stream.puts( '<?xml version="1.0" encoding="utf-8" ?>' )
    stream.puts( "<TestRun>" )
  end

  # CppUnit XML test list contents
  def body(results:, stream:)
    @test_counter = 1
    write_failures( results[:failures], stream )
    write_tests( results[:successes], stream, 'SuccessfulTests' )
    write_tests( results[:ignores], stream, 'IgnoredTests' )
    write_statistics( results[:counts], stream )
  end

  # CppUnit XML footer
  def footer(results:, stream:)
    stream.puts( "</TestRun>" )
  end

  ### Private

  private

  def write_failures(results, stream)
    if results.size.zero?
      stream.puts( "  <FailedTests/>" )
      return
    end

    stream.puts( "  <FailedTests>" )

    results.each do |result|
      result[:collection].each do |item|
        filename = result[:source][:file]

        stream.puts "    <Test id=\"#{@test_counter}\">"
        stream.puts "      <Name>#{filename}::#{item[:test]}</Name>"
        stream.puts "      <FailureType>Assertion</FailureType>"
        stream.puts "      <Location>"
        stream.puts "        <File>#{filename}</File>"
        stream.puts "        <Line>#{item[:line]}</Line>"
        stream.puts "      </Location>"
        stream.puts "      <Message>#{item[:message]}</Message>"
        stream.puts "    </Test>"
        @test_counter += 1
      end
    end

    stream.puts( "  </FailedTests>" )
  end

  def write_tests(results, stream, tag)
    if results.size.zero?
      stream.puts( "  <#{tag}/>" )
      return
    end

    stream.puts( "  <#{tag}>" )

    results.each do |result|
      result[:collection].each do |item|
        filename = result[:source][:file]
        stream.puts( "    <Test id=\"#{@test_counter}\">" )
        stream.puts( "      <Name>#{filename}::#{item[:test]}</Name>" )
        stream.puts( "    </Test>" )
        @test_counter += 1
      end
    end

    stream.puts "  </#{tag}>"
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
