# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tests_reporter'

class JunitTestsReporter < TestsReporter

  def setup()
    super( default_filename: 'junit_tests_report.xml' )
  end

  def header(results:, stream:)
    stream.puts( '<?xml version="1.0" encoding="utf-8" ?>' )
    stream.puts(
      '<testsuites tests="%d" '    % results[:counts][:total] +
                  'failures="%d" ' % results[:counts][:failed] +
                  'time="%.3f">'   % results[:total_time]
    )
  end

  def body(results:, stream:)
    suites = reorganize_results( results )

    suites.each do |suite|
      write_suite( suite, stream )
    end
  end

  def footer(results:, stream:)
    stream.puts( '</testsuites>' )
  end

  ### Private

  private

  # Reorganize test results by test executable instead of by result category
  # Original success structure: successeses { file => test_cases[] }
  # Reorganized test results:   file => test_cases[{... result: :success}]
  def reorganize_results( results )
    # Create structure of hash with default values
    suites = Hash.new() do |h,k|
      h[k] = {
        collection: [],
        total:   0,
        success: 0,
        failed:  0,
        ignored: 0,
        errors:  0,
        time:    0,
        stdout:  []
      }
    end

    results[:successes].each do |result|
      # Extract filepath
      source = result[:source][:file]

      # Filepath minus file extension
      name = source.sub( /#{File.extname(source)}$/, '' )

      # Sanitize: Ensure no nil elements
      result[:collection].compact!

      # Sanitize: Ensure no empty test result hashes
      result[:collection].select! {|test| !test.empty?() }

      # Add success test cases to full test case collection and update statistics
      suites[name][:collection] += result[:collection].map{|test| test.merge(result: :success)}
      suites[name][:total] += result[:collection].length
      suites[name][:success] += result[:collection].length
      suites[name][:time] = results[:times][source]
    end

    results[:failures].each do |result|
      # Extract filepath
      source = result[:source][:file]

      # Filepath minus file extension
      name = source.sub( /#{File.extname(source)}$/, '' )

      # Sanitize: Ensure no nil elements
      result[:collection].compact!

      # Sanitize: Ensure no empty test result hashes
      result[:collection].select! {|test| !test.empty?() }

      # Add failure test cases to full test case collection and update statistics
      suites[name][:collection] += result[:collection].map{|test| test.merge(result: :failed)}
      suites[name][:total] += result[:collection].length
      suites[name][:failed] += result[:collection].length
      suites[name][:time] = results[:times][source]
    end

    results[:ignores].each do |result|
      # Extract filepath
      source = result[:source][:file]

      # Filepath minus file extension
      name = source.sub( /#{File.extname(source)}$/, '' )

      # Sanitize: Ensure no nil elements
      result[:collection].compact!

      # Sanitize: Ensure no empty test result hashes
      result[:collection].select! {|test| !test.empty?() }

      # Add ignored test cases to full test case collection and update statistics
      suites[name][:collection] += result[:collection].map{|test| test.merge(result: :ignored)}
      suites[name][:total] += result[:collection].length
      suites[name][:ignored] += result[:collection].length
      suites[name][:time] = results[:times][source]
    end

    results[:stdout].each do |result|
      # Extract filepath
      source = result[:source][:file]
      # Filepath minus file extension
      name = source.sub( /#{File.extname(source)}$/, '' )

      # Add $stdout messages to collection
      suites[name][:stdout] += result[:collection]
    end

    # Add name to suite hashes (duplicating the key for suites)
    suites.map{|name, data| data.merge(name: name) }
  end

  def write_suite( suite, stream )
    stream.puts(
      '  <testsuite name="%s" '     % suite[:name] +
                   'tests="%d" '    % suite[:total] +
                   'failures="%d" ' % suite[:failed] +
                   'skipped="%d" '  % suite[:ignored] +
                   'errors="%d" '   % suite[:errors] +
                   'time="%.3f">'   % suite[:time]
    )

    suite[:collection].each do |test|
      write_test( test, stream )
    end

    unless suite[:stdout].empty?
      stream.puts('    <system-out>')
      suite[:stdout].each do |line|
        line.gsub!(/&/, '&amp;')
        line.gsub!(/</, '&lt;')
        line.gsub!(/>/, '&gt;')
        line.gsub!(/"/, '&quot;')
        line.gsub!(/'/, '&apos;')
        stream.puts( line )
      end
      stream.puts('    </system-out>')
    end

    stream.puts('  </testsuite>')
  end

  def write_test( test, stream )
    test[:test].gsub!(/&/, '&amp;')
    test[:test].gsub!(/</, '&lt;')
    test[:test].gsub!(/>/, '&gt;')
    test[:test].gsub!(/"/, '&quot;')
    test[:test].gsub!(/'/, '&apos;')

    case test[:result]
    when :success
      stream.puts(
        '    <testcase name="%<test>s" '               % test +
                      'time="%<unity_test_time>.3f"/>' % test
      )

    when :failed
      stream.puts(
        '    <testcase name="%<test>s" '              % test +
                      'time="%<unity_test_time>.3f">' % test
      )

      if test[:message].empty?
        stream.puts( '      <failure />' )
      else
        stream.puts( '      <failure message="%s" />' % test[:message] )
      end
      
      stream.puts( '    </testcase>' )

    when :ignored
      stream.puts( '    <testcase name="%<test>s" time="%<unity_test_time>.3f">' % test )
      stream.puts( '      <skipped />' )
      stream.puts( '    </testcase>' )
    end
  end
end
