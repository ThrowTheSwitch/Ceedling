# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'

class ReportTestsLogFactory < Plugin
  
  # `Plugin` setup()
  def setup
    # Hash: Context => Array of test executable results files
    @results = {}
    
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

  # `Plugin` build step hook -- collect context:results_filepath after test fixture runs
  def post_test_fixture_execute(arg_hash)
    # Do nothing if no reports configured
    return if not @enabled

    # Get context from test run
    context = arg_hash[:context]

    @mutex.synchronize do
      # Create an empty array if context does not already exist as a key
      @results[context] = [] if @results[context].nil?

      # Add results filepath to array at context key
      @results[context] << arg_hash[:result_file]
    end
  end

  # `Plugin` build step hook -- process results into log files after test build completes
  def post_build
    # Do nothing if no reports configured
    return if not @enabled

    empty = false

    @mutex.synchronize { empty = @results.empty? }

    # Do nothing if no results were generated (e.g. not a test build)
    return if empty

    msg = @reportinator.generate_heading( "Running Test Suite Reports" )
    @loginator.log( msg )

    @mutex.synchronize do
      # For each configured reporter, generate a test suite report per test context
      @results.each do |context, results_filepaths|
        # Assemble results from all results filepaths collected
        _results = @ceedling[:plugin_reportinator].assemble_test_results( results_filepaths )

        # Provide results to each Reporter
        @reporters.each do |reporter|
          filepath = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s, reporter.filename )

          msg = @reportinator.generate_progress( "Generating artifact #{filepath}" )
          @loginator.log( msg )

          reporter.write( filepath: filepath, results: _results )
        end
      end
    end

  # White space at command line after progress messages
  @loginator.log( '' )
  end

  ### Private

  private

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
