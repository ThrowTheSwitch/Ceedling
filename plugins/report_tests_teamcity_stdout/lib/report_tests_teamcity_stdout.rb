# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/defaults'

class ReportTestsTeamcityStdout < Plugin

  # `Plugin` setup()
  def setup
    # TEAMCITY_BUILD defaults to true but can be overridden in a user 
    # project file to stop CI messages locally.
    @output_enabled = TEAMCITY_BUILD

    # Provide thread-safety for multi-threaded builds
    @mutex = Mutex.new

    # A counter incremented for each Ceedling test executable allowing 
    # concurrent executables to differentiate their service messages.
    @flowid_count = 0

    # A TeamCity suite correlates to a Ceedling test executable
    # This hash relates each test filepath to a unique Flow ID
    # (TeamCity uses Flow IDs to differentiate messages generated in concurrent threads)
    @suites = {}

    # Captured rather than called as a bare `puts` so a test can substitute
    # a StringIO -- deliberately not routed through Loginator, which would
    # risk both suppression under a quiet --verbosity and batching/timing
    # changes to what TeamCity expects as immediate, real-time messages.
    @stream = $stdout
  end

  # `Plugin` build step hook
  def pre_test(test)
    return if !@output_enabled

    # Generate a new Flow ID and open the test's suite. A suite is named for its test,
    # which tells same-named tests in different directories apart.
    @mutex.synchronize do
      @flowid_count += 1
      @suites[test] = { :flowid => @flowid_count, :name => escape( @ceedling[:file_path_utils].form_test_name( test ) ) }

      teamcity_service_message( "testSuiteStarted name='#{@suites[test][:name]}'", @suites[test][:flowid] )
    end
  end

  # `Plugin` build step hook
  def post_test_fixture_execute(arg_hash)
    return if !@output_enabled

    flowId = @mutex.synchronize { @suites[arg_hash[:test_filepath]][:flowid] }

    # Gather test results for this test executable
    results = @ceedling[:plugin_reportinator].assemble_test_results( [arg_hash[:result_file]] )
    duration = average_duration( results )

    context = arg_hash[:context]

    report_successes( results[:successes], context, flowId, duration )
    report_failures( results[:failures], context, flowId, duration )
    report_ignores( results[:ignores], context, flowId )
  end

  # `Plugin` build step hook
  def post_test(test)
    return if !@output_enabled

    @mutex.synchronize do
      teamcity_service_message(
        "testSuiteFinished name='#{@suites[test][:name]}'",
        @suites[test][:flowid]
      )
    end
  end

  ### Private

  private

  # Total run time of a test executable, apportioned equally to each test case within it, in ms
  def average_duration(results)
    duration_ms = results[:total_time] * 1000.0

    return (duration_ms / [1, results[:counts][:passed] + results[:counts][:failed]].max).round
  end

  def report_successes(successes, context, flowId, duration)
    successes.each do |success|
      success[:collection].each do |test|
        name = test_name( context, success[:source], test[:test] )

        teamcity_service_message( "testStarted name='#{name}'", flowId )
        teamcity_service_message( "testFinished name='#{name}' duration='#{duration}'", flowId )
      end
    end
  end

  def report_failures(failures, context, flowId, duration)
    failures.each do |failure|
      failure[:collection].each do |test|
        name = test_name( context, failure[:source], test[:test] )
        details = escape( "File: #{failure[:source][:file]} Line: #{test[:line]}" )

        teamcity_service_message( "testStarted name='#{name}'", flowId )
        teamcity_service_message( "testFailed name='#{name}' message='#{escape( test[:message] )}' details='#{details}'", flowId )
        teamcity_service_message( "testFinished name='#{name}' duration='#{duration}'", flowId )
      end
    end
  end

  def report_ignores(ignores, context, flowId)
    ignores.each do |ignored|
      ignored[:collection].each do |test|
        teamcity_service_message( "testIgnored name='#{test_name( context, ignored[:source], test[:test] )}'", flowId )
      end
    end
  end

  # A Java-like name per TeamCity convention `package_or_namespace.ClassName.TestName`
  #  ==> `context.TestFilepath.TestCaseName`, escaped
  def test_name(context, source, test)
    filepath = File.join( source[:dirname], File.basename( source[:basename], '.*' ) )

    return escape( "#{context}.#{filepath}.#{test}" )
  end

  def escape(string)
    # https://www.jetbrains.com/help/teamcity/service-messages.html#Escaped+Values
    # A real embedded CR/LF must become the two-character |r/|n sequence, not
    # pass through as an actual line break -- TeamCity parses service
    # messages one physical line at a time, so an unescaped newline mid
    # message would split it across lines and corrupt the message TeamCity
    # sees.
    string.gsub(/['|\[\]]/, '|\0').gsub("\r", '|r').gsub("\n", '|n')
  end

  def teamcity_service_message(content, flowId=0)
    # https://www.jetbrains.com/help/teamcity/service-messages.html
    @stream.puts "##teamcity[#{content} flowId='#{flowId}']"
  end

end
