require 'ceedling/plugin'
require 'ceedling/constants'

class TestSuiteReporter < Plugin
  def setup
    @reports = []
    @results_list = {}
    
    config = @ceedling[:configurator].project_config_hash

    reports = config[:test_suite_reporter_reports]
    reports.each do |report|
      # Load each reporter object dynamically by convention
      require "#{report}_reporter"
      @reports << eval( "#{report.capitalize()}Reporter.new('log.json', @ceedling)" )
    end

    @enabled = !(reports.empty?)
  end

  def post_test_fixture_execute(arg_hash)
    return if not @enabled

    context = arg_hash[:context]

    @results_list[context] = [] if @results_list[context].nil?

    @results_list[context] << arg_hash[:result_file]
  end

  def post_build
    return if not @enabled

    @reports.each do |report|
      report.write( @results_list )
    end
  end

end
