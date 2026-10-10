# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'tests_reporter'

class ReportTestsLogFactory < Plugin

  TestBuild = Struct.new( :results_filepaths, :start_time_s, :end_time_s )

  # `Plugin` setup()
  def setup
    # Hash: Context symbol => TestBuild struct
    @build_results = {}

    config     = @ceedling[:setupinator].config_hash[:report_tests_log_factory]
    @reporters = load_reporters( config[:reports], config )

    # With no reports configured, every hook does nothing
    @enabled = !@reporters.empty?

    @mutex = Mutex.new()

    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
  end

  def pre_test_build(context, timestamp_s)
    return if not @enabled

    # Initialize a TestBuild entry for this test context
    @build_results[context] = TestBuild.new( [], timestamp_s, nil )
  end

  # `Plugin` build step hook -- collect context:results_filepath after test fixture runs
  def post_test_fixture_execute(arg_hash)
    # Do nothing if no reports configured
    return if not @enabled

    # Get context from test run
    context = arg_hash[:context]

    @mutex.synchronize do
      # Fixtures run inside a test build, so pre_test_build has normally made this entry.
      # Without one, the results are still reported, with no duration.
      @build_results[context] ||= TestBuild.new( [], nil, nil )
      @build_results[context].results_filepaths << arg_hash[:result_file]
    end
  end

  def post_test_build(context, timestamp_s)
    return if not @enabled

    @mutex.synchronize do
      @build_results[context].end_time_s = timestamp_s if @build_results[context]
    end
  end

  # `Plugin` build step hook -- process results into log files after test build completes
  def post_build(_timestamp_s)
    # Do nothing if no reports configured or no results collected (e.g. not a test build)
    return if not @enabled
    return if @build_results.empty?

    reporting do
      @build_results.each do |context, test_build|
        results = @ceedling[:plugin_reportinator].assemble_test_results( test_build.results_filepaths )
        write_reports( context, results, duration_s( test_build ) )
      end
    end
  end

  # `Plugin` summary hook -- report on the test results an earlier build left on disk.
  # No build ran, so there is no duration. Only the test context's results are read.
  def summary
    return if not @enabled

    result_list = @ceedling[:file_path_utils].form_pass_results_filelist( PROJECT_TEST_RESULTS_PATH, COLLECTION_ALL_TESTS )
    results     = @ceedling[:plugin_reportinator].assemble_test_results( result_list, {:boom => false} )

    reporting { write_reports( TEST_SYM, results, nil ) }
  end

  # The class a configured report loads by convention, e.g. 'fancy_shmancy' loads
  # FancyShmancyTestsReporter
  def self.reporter_class_name(report)
    camel = report.gsub( /_./ ) { |match| match.upcase.delete( '_' ) }
    return camel[0].capitalize + camel[1..] + 'TestsReporter'
  end

  ### Private

  private

  # Frames report generation's progress messages with a heading and trailing white space
  def reporting
    @loginator.log( @reportinator.generate_heading( "Running Test Suite Reports" ) )
    yield
    @loginator.log( '' )
  end

  # Writes every configured report for one context under that context's artifacts directory
  def write_reports(context, results, duration_s)
    name = generate_report_name( context )

    @reporters.each do |reporter|
      filepath = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s, reporter.filename )
      @loginator.log( @reportinator.generate_progress( "Generating artifact #{filepath}" ) )
      reporter.write( name: name, filepath: filepath, results: results, duration_s: duration_s )
    end
  end

  # A build's duration, or nil when either end of it went unrecorded
  def duration_s(test_build)
    start_s = test_build.start_time_s
    end_s   = test_build.end_time_s
    return (start_s && end_s) ? (end_s - start_s) : nil
  end

  # The display name in report titles and headers. A context other than the default test
  # context prefixes it.
  def generate_report_name(context)
    name = @ceedling[:configurator].project_name.to_s.strip
    name = TestsReporter::DEFAULT_REPORT_NAME if name.empty?

    return name if context == TEST_SYM
    return "[#{context.to_s.upcase}] #{name}"
  end

  # Each configured report loads its Reporter subclass by naming convention. The factory
  # injects configuration and utilities, which keeps a custom subclass's own setup small.
  # A report named twice is written once.
  def load_reporters(reports, config)
    return reports.map( &:downcase ).uniq.map { |report| load_reporter( report, config[report.to_sym] ) }
  end

  def load_reporter(report, config)
    # A custom subclass's directory must be in :plugins ↳ :load_paths
    require "#{report}_tests_reporter"

    # A custom subclass that breaks the naming convention fails with a NameError naming
    # the missing class
    reporter = Object.const_get( ReportTestsLogFactory.reporter_class_name( report ) ).new( handle: report.to_sym )

    reporter.config            = config
    reporter.config_walkinator = @ceedling[:config_walkinator]
    reporter.file_wrapper      = @ceedling[:file_wrapper]
    reporter.setup()

    return reporter
  end

end
