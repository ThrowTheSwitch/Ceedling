# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'

class ReportTestsLogFactory < Plugin

  DEFAULT_REPORT_NAME = "Ceedling Test Suite"

  TestBuild = Struct.new( :results_filepaths, :start_time_s, :end_time_s )

  # `Plugin` setup()
  def setup
    # Hash: Context symbol => TestBuild struct
    @build_results = {}
    
    # Get our test suite reports' configuration
    config = @ceedling[:setupinator].config_hash
    @config = config[:report_tests_log_factory]
    
    # Get list of enabled reports
    reports = @config[:reports]

    # Array of Reporter subclass objects
    @reporters = load_reporters( reports, @config )

    # Disable this plugin if no reports configured
    @enabled = !(reports.empty?)

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
      # Create a TestBuild entry if pre_test_build did not fire for this context.
      # `ceedling summary` will not fire pre_test_build.
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

    msg = @reportinator.generate_heading( "Running Test Suite Reports" )
    @loginator.log( msg )

    # For each configured reporter, generate a test suite report per test context
    @build_results.each do |context, test_build|
      # Assemble results from all results filepaths collected
      _results = @ceedling[:plugin_reportinator].assemble_test_results( test_build.results_filepaths )

      # Provide results to each Reporter
      @reporters.each do |reporter|
        filepath = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s, reporter.filename )
        name = generate_report_name( context )

        msg = @reportinator.generate_progress( "Generating artifact #{filepath}" )
        @loginator.log( msg )

        start_s    = test_build.start_time_s
        end_s      = test_build.end_time_s
        duration_s = (start_s && end_s) ? (end_s - start_s) : nil
        reporter.write(
          name: name,
          filepath: filepath,
          results: _results,
          duration_s: duration_s
        )
      end
    end

  # White space at command line after all progress messages
  @loginator.log( '' )
  end

  # `Plugin` summary hook -- generate reports from existing results in the build directory
  def summary
    return if not @enabled

    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(
      PROJECT_TEST_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    _results = @ceedling[:plugin_reportinator].assemble_test_results( result_list, {boom: false} )

    msg = @reportinator.generate_heading( "Running Test Suite Reports" )
    @loginator.log( msg )

    @reporters.each do |reporter|
      filepath = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, TEST_SYM.to_s, reporter.filename )

      msg = @reportinator.generate_progress( "Generating artifact #{filepath}" )
      @loginator.log( msg )

      reporter.write(
        name: DEFAULT_REPORT_NAME,
        filepath: filepath,
        results: _results
      )
    end

    @loginator.log( '' )
  end

  ### Private

  private

  def generate_report_name(context)
      # Resolve and inject the display name used in report titles/headers.

      # Start with project name from configuration
      _name = @ceedling[:configurator].project_name.to_s.strip

      # Default to a generic name if project name is empty
      name = _name.empty? ? DEFAULT_REPORT_NAME : _name

      # Prepend name with context if not the default test context (TEST_SYM)
      if context != TEST_SYM
        name = "[#{context.to_s.upcase}] #{name}"
      end

      return name
  end

  def load_reporters(reports, config)
    reporters = []

    # For each report name string in configuration, dynamically load the corresponding 
    # Reporter subclass by convention

    # The steps below limit the set up complexity that would otherwise be
    # required of a user's custom Reporter subclass
    reports.each do |report|
      # Enforce lowercase convention internally
      report = report.downcase()

      # Convert report configuration name 'foo_bar' to 'FooBarTestReporter' class name
      #  1. Convert 'x_Y' (snake case) to camel case ('xY')
      #  2. Capitalize first character of config name and add rest of class name
      _reporter = report.gsub(/_./) {|match| match.upcase().delete('_') }
      _reporter = _reporter[0].capitalize() + _reporter[1..-1] + 'TestsReporter'

      # Load each Reporter sublcass Ruby file dynamically by convention
      # For custom user subclasses, requires directoy in :plugins ↳ :load_paths
      require "#{report}_tests_reporter"

      # Dynamically instantiate Reporter subclass object
      reporter = eval( "#{_reporter}.new(handle: :#{report})" )

      # Inject configuration
      reporter.config = config[report.to_sym]

      # Inject utilty object
      reporter.config_walkinator = @ceedling[:config_walkinator]

      # Perform Reporter sublcass set up
      reporter.setup()

      # Add new object to our internal list
      reporters << reporter
    end

    return reporters
  end

end
