require 'ceedling/plugin'
require 'ceedling/defaults'

class TeamcityTestsReport < Plugin
  
  def setup
    @suite_started = nil
  end

  def escape(string)
    string.gsub(/['|\[\]]/, '|\0').gsub('\r', '|r').gsub('\n', '|n')
  end

  def pre_test(test)
    puts "##teamcity[testSuiteStarted name='#{File.basename(test, '.c')}']"
    @suite_started = Time.now
  end

  def post_test(test)
    puts "##teamcity[testSuiteFinished name='#{File.basename(test, '.c')}']"
  end

  def post_test_fixture_execute(arg_hash)
    duration = (Time.now - @suite_started) * 1000

    results = @ceedling[:plugin_reportinator].assemble_test_results([arg_hash[:result_file]])

    avg_duration = (duration / [1, results[:counts][:passed] + results[:counts][:failed]].max).round

    results[:successes].each do |success|
      success[:collection].each do |test|
        puts "##teamcity[testStarted name='#{test[:test]}']"
        puts "##teamcity[testFinished name='#{test[:test]}' duration='#{avg_duration}']"
      end
    end

    results[:failures].each do |failure|
      failure[:collection].each do |test|
        puts "##teamcity[testStarted name='#{test[:test]}']"
        puts "##teamcity[testFailed name='#{test[:test]}' message='#{escape(test[:message])}' details='File: #{failure[:source][:path]}/#{failure[:source][:file]} Line: #{test[:line]}']"
        puts "##teamcity[testFinished name='#{test[:test]}' duration='#{avg_duration}']"
      end
    end

    results[:ignores].each do |failure|
      failure[:collection].each do |test|
        puts "##teamcity[testIgnored name='#{test[:test]}' message='#{escape(test[:message])}']"
      end
    end

    # We ignore stdout
  end


end
