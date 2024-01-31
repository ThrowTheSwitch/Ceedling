require 'ceedling/plugin'
require 'ceedling/defaults'

class StdoutTeamcityTestsReport < Plugin

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
  end

  # Hook run before each test executable begins building
  def pre_test(test)
    return if !@output_enabled

    # Generate a new Flow ID and store it in test hash
    @mutex.synchronize do
      @flowid_count += 1
      @suites[test] = { :flowid => @flowid_count }
    end

    # Generate first TeamCity service message
    @mutex.synchronize do
      teamcity_service_message(
        "testSuiteStarted name='#{File.basename(test, '.*')}'",
        @suites[test][:flowid]
      )
    end
  end

  # Hook run after test executable is run
  def post_test_fixture_execute(arg_hash)
    return if !@output_enabled

    flowId = nil
    test_key = arg_hash[:test_filepath]

    # Get unique Flow ID
    @mutex.synchronize do
      flowId = @suites[test_key][:flowid]
    end

    # Gather test results for this test executable
    results = @ceedling[:plugin_reportinator].assemble_test_results( [arg_hash[:result_file]] )

    # Apportion total run time of test executable equally to each test case within it.
    duration_ms = results[:total_time] * 1000.0
    avg_duration = (duration_ms / [1, results[:counts][:passed] + results[:counts][:failed]].max).round

    # Handle test case successes within the test executable
    results[:successes].each do |success|
      success[:collection].each do |test|
        _test = test[:test]

        teamcity_service_message(
          "testStarted name='#{_test}'",
          flowId
        )

        teamcity_service_message(
          "testFinished name='#{_test}' duration='#{avg_duration}'",
          flowId
        )
      end
    end

    # Handle test case failures within the test executable
    results[:failures].each do |failure|
      failure[:collection].each do |test|
        _test = test[:test]
        _message = test[:message]

        teamcity_service_message(
          "testStarted name='#{_test}'",
          flowId
        )

        _message = 
          "testFailed name='#{_test}' " + 
          "message='#{escape(_message)}' " +
          "details='File: #{failure[:source][:file]} Line: #{test[:line]}'"

        teamcity_service_message( _message, flowId )

        teamcity_service_message(
          "testFinished name='#{_test}' duration='#{avg_duration}'",
          flowId
        )
      end
    end

    # Handle ignored tests
    results[:ignores].each do |failure|
      failure[:collection].each do |test|
        _test = test[:test]

        service_message = "testIgnored name='#{_test}'"

        teamcity_service_message( service_message )
      end
    end

  end

  # Hook run after a test executable build
  def post_test(test)
    return if !@output_enabled

    @mutex.synchronize do
      teamcity_service_message(
        "testSuiteFinished name='#{File.basename(test, '.*')}'",
        @suites[test][:flowid]
      )
    end
  end

  ### Private

  private

  def escape(string)
    # https://www.jetbrains.com/help/teamcity/service-messages.html#Escaped+Values
    string.gsub(/['|\[\]]/, '|\0').gsub('\r', '|r').gsub('\n', '|n')
  end

  def teamcity_service_message(content, flowId=0)
    # https://www.jetbrains.com/help/teamcity/service-messages.html
    puts "##teamcity[#{content} flowId='#{flowId}']"
  end

end
