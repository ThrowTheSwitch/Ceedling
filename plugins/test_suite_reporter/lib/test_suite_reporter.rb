require 'ceedling/plugin'

class TestSuiteReporter < Plugin
  def setup
    # Hash: Context => Array of test executable results files
    @results = {}
    
    # Get our test suite reports' configuration
    config = @ceedling[:setupinator].config_hash
    @config = config[:test_suite_reporter]
    
    # Get reports list
    reports = @config[:reports]

    # Hash: Report name => Reporter object
    @reporters = load_reporters( reports, @config )

    # Disable this plugin if no reports configured
    @enabled = !(reports.empty?)

    @streaminator = @ceedling[:streaminator]
    @reportinator = @ceedling[:reportinator]
  end

  # Plugin hook -- collect context:results_filepath after test fixture runs
  def post_test_fixture_execute(arg_hash)
    # Do nothing if no reports configured
    return if not @enabled

    # Get context from test run
    context = arg_hash[:context]

    # Create an empty array if context does not already exist as a key
    @results[context] = [] if @results[context].nil?

    # Add results filepath to array at context key
    @results[context] << arg_hash[:result_file]
  end

  # Plugin hook -- process results into log files after test build completes
  def post_build
    # Do nothing if no reports configured
    return if not @enabled

    # Do nothing if no results were generated (e.g. not a test build)
    return if @results.empty?

    # For each configured reporter, generate a test suite report per test context
    @reporters.each do |reporter|
      @results.each do |context, results_filepaths|
        # Assemble results from all results filepaths collected
        _results = @ceedling[:plugin_reportinator].assemble_test_results( results_filepaths )

        filepath = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s, reporter.filename )

        msg = @reportinator.generate_progress( "Generating tests report artifact #{filepath}" )
        @streaminator.stdout_puts( msg )

        reporter.write( filepath: filepath, results: _results )
      end
    end
  end

  ### Private

  private

  def load_reporters(reports, config)
    reporters = []

    # For each report name string, dynamically load the corresponding class
    reports.each do |report|
      # The steps below limit the set up complexity that would otherwise be
      # required of a user's custom derived Reporter subclass

      # Load each reporter object dynamically by convention
      require "scripts/#{report}_tests_reporter.rb"

      # Dynamically instantiate reporter subclass
      reporter = eval( "#{report.capitalize()}TestsReporter.new()" )

      # Set internal name
      reporter.handle = report.to_sym

      # Inject configuration
      reporter.config = config[report.to_sym] 
      
      # Inject utilty object
      reporter.config_walkinator = @ceedling[:config_walkinator]

      # Perform Reporter set up
      reporter.setup()

      reporters << reporter
    end

    return reporters
  end

end
