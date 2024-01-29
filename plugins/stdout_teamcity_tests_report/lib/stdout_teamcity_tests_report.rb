require 'ceedling/plugin'
require 'ceedling/defaults'

class StdoutTeamcityTestsReport < Plugin

  def setup
    @suite_started = nil

    # TEAMCITY_BUILD defaults to true but can be overridden in a user project file to stop CI messages locally
    @output_enabled = TEAMCITY_BUILD

    @mutex = Mutex.new

    @flowid_count = 1

    # A TeamCity suite correlates to a test executable
    # This hash tracks:
    #  - Suite start time
    #  - Flow ID (to differentiate tests running in concurrent threads)
    @suites = {}
  end

  def pre_test(test)
    return if !@output_enabled

    @mutex.synchronize do
      @suites[test] = {
        :started => Time.now(),
        :flowid => @flowid_count
      }
      @flowid_count += 1
    end

    @mutex.synchronize do
      teamcity_service_message(
        "testSuiteStarted name='#{File.basename(test, '.*')}'",
        @suites[test][:flowid]
      )
    end
  end

  def post_test(test)
    return if !@output_enabled

    @mutex.synchronize do
      teamcity_service_message(
        "testSuiteFinished name='#{File.basename(test, '.*')}'",
        @suites[test][:flowid]
      )
    end
  end

  def post_test_fixture_execute(arg_hash)
    return if !@output_enabled

    _duration_ms = nil
    _flowId = nil
    test_key = arg_hash[:test]

    @mutex.synchronize do
      _duration_ms = (Time.now() - @suites[test_key][:started]) * 1000
      _flowId = @suites[test_key][:flowid]
    end

    results = @ceedling[:plugin_reportinator].assemble_test_results([arg_hash[:result_file]])
    avg_duration = (_duration_ms / [1, results[:counts][:passed] + results[:counts][:failed]].max).round

    results[:successes].each do |success|
      success[:collection].each do |test|
        _test = test[:test]

        teamcity_service_message(
          "testStarted name='#{_test}'",
          _flowId
        )

        teamcity_service_message(
          "testFinished name='#{_test}' duration='#{avg_duration}'",
          _flowId
        )
      end
    end

    results[:failures].each do |failure|
      failure[:collection].each do |test|
        _test = test[:test]
        _message = test[:message]

        teamcity_service_message(
          "testStarted name='#{_test}'",
          _flowId
        )

        _message = 
          "testFailed name='#{_test}' " + 
          # Always a message in a test failure
          "message='#{escape(_message)}' " +
          "details='File: #{failure[:source][:file]} Line: #{test[:line]}'"

        teamcity_service_message( _message, _flowId )

        teamcity_service_message(
          "testFinished name='#{_test}' duration='#{avg_duration}'",
          _flowId
        )
      end
    end

    results[:ignores].each do |failure|
      failure[:collection].each do |test|
        _test = test[:test]

        service_message = "testIgnored name='#{_test}'"

        teamcity_service_message( service_message )
      end
    end

  end

  ### Private

  private

  def escape(string)
    string.gsub(/['|\[\]]/, '|\0').gsub('\r', '|r').gsub('\n', '|n')
  end

  def teamcity_service_message(content, flowId=0)
    puts "##teamcity[#{content} flowId='#{flowId}']"
  end

end
