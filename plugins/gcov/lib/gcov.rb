require 'ceedling/plugin'
require 'ceedling/constants'
require 'gcov_constants'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'

class Gcov < Plugin
  attr_reader :config

  def setup
    @result_list = []

    @config = {
      gcov_html_report_filter: GCOV_FILTER_EXCLUDE
    }

    @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @coverage_template_all = @ceedling[:file_wrapper].read(File.join(@plugin_root, 'assets/template.erb'))

    config = @ceedling[:configurator].project_config_hash
    @reports_enabled = reports_enabled?( config[:gcov_reports] )

    # This may raise an exception because of configuration or tool installation issues.
    # Best to complain about it before allowing any tasks to run.
    @reportinators = build_reportinators( config[:gcov_utilities], @reports_enabled )
  end

  def generate_coverage_object_file(test, source, object)
    tool = TOOLS_TEST_COMPILER
    msg = nil

    # If a source file (not unity, mocks, etc.) is to be compiled use code coverage compiler
    if @ceedling[:configurator].collection_all_source.to_a.include?(source)
      tool = TOOLS_GCOV_COMPILER
      msg = "Compiling #{File.basename(source)} with coverage..."
    end

    @ceedling[:test_invoker].compile_test_component(
      tool:    tool,
      context: GCOV_SYM,
      test:    test,
      source:  source,
      object:  object,
      msg:     msg
      )
  end

  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    if (result_file =~ /#{GCOV_RESULTS_PATH}/) && !@result_list.include?(result_file)
      @result_list << arg_hash[:result_file]
    end
  end

  def post_build
    # Do nothing unless a gcov: task was used
    return unless @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)

    # Assemble test results
    results = @ceedling[:plugin_reportinator].assemble_test_results(@result_list)
    hash = {
      header: GCOV_ROOT_NAME.upcase,
      results: results
    }

    # Print unit test suite results
    @ceedling[:plugin_reportinator].run_test_results_report(hash) do
      message = ''
      message = 'Unit test failures.' if results[:counts][:failed] > 0
      message
    end

    # Prinnt a short report of coverage results for each source file exercised by a test
    report_per_file_coverage_results()

    # Run coverage report generation
    generate_coverage_reports() if not automatic_reporting_disabled?
  end

  def summary
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(GCOV_RESULTS_PATH, COLLECTION_ALL_TESTS)

    # Get test results for only those tests in our configuration and for those only tests with results on disk
    hash = {
      header: GCOV_ROOT_NAME.upcase,
      results: @ceedling[:plugin_reportinator].assemble_test_results(result_list, boom: false)
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
  end

  def automatic_reporting_disabled?
    config = @ceedling[:configurator].project_config_hash

    task = config[:gcov_report_task]

    return task if not task.nil?

    return false
  end

  def generate_coverage_reports
    return if (not @reports_enabled) or @reportinators.empty?

    # Create the artifacts output directory.
    @ceedling[:file_wrapper].mkdir( GCOV_ARTIFACTS_PATH )

    @reportinators.each do |reportinator|
      reportinator.make_reports( @ceedling[:configurator].project_config_hash )
    end
  end

  private ###################################

  def report_per_file_coverage_results()
    banner = @ceedling[:plugin_reportinator].generate_banner( "#{GCOV_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @ceedling[:streaminator].stdout_puts "\n" + banner

    # Iterate over each test run and its list of source files
    @ceedling[:test_invoker].each_test_with_sources do |test, sources|
      heading = @ceedling[:plugin_reportinator].generate_heading( test )
      @ceedling[:streaminator].stdout_puts(heading)

      sources.each do |source|
        filename = File.basename(source)
        name     = filename.ext('')
        command  = @ceedling[:tool_executor].build_command_line(
                     TOOLS_GCOV_REPORT,
                     [], # No additional arguments
                     filename, # .c source file that should have been compiled with coverage
                     File.join(GCOV_BUILD_OUTPUT_PATH, test) # <build>/gcov/out/<test name> for coverage data files
                   )

        # Run the gcov tool and collect raw coverage report
        shell_results  = @ceedling[:tool_executor].exec(command[:line], command[:options])
        results        = shell_results[:output].strip

        # Skip to next loop iteration if no coverage results.
        # A source component may have been compiled with coverage but none of its code actually called in a test.
        # In this case, gcov does not produce an error, only blank results.
        if results.empty?
          @ceedling[:streaminator].stdout_puts("#{filename} : No functions called or code paths exercised by test\n")
          next
        end

        # If results include intended source, extract details from console
        if results =~ /(File\s+'#{Regexp.escape(source)}'.+$)/m
          # Reformat from first line as filename banner to each line labeled with the filename
          # Only extract the first four lines of the console report (to avoid spidering coverage reports through libs, etc.)
          report = Regexp.last_match(1).lines.to_a[1..4].map { |line| filename + ' | ' + line }.join('')
          @ceedling[:streaminator].stdout_puts(report + "\n")
        
        # Otherwise, no coverage results were found
        else
          msg = "ERROR: Could not find coverage results for #{source} component of #{test}"
          @ceedling[:streaminator].stderr_puts( msg, Verbosity::NORMAL )
        end
      end
    end
  end

  def reports_enabled?(cfg_reports)
    return false if cfg_reports.nil? or cfg_reports.empty?
    return true
  end

  def build_reportinators(cfg_utils, enabled)
    reportinators = []

    return [] if not enabled

    # Remove unsupported reporting utilities.
    if (not cfg_utils.nil?)
      cfg_utils.reject! { |item| !(UTILITY_NAMES.map(&:upcase).include? item.upcase) }
    end

    # Default to gcovr when no reporting utilities are specified.
    if cfg_utils.nil? || cfg_utils.empty?
      cfg_utils = [UTILITY_NAME_GCOVR]
    end

    # Run reports using gcovr
    if utility_enabled?( cfg_utils, UTILITY_NAME_GCOVR )
      reportinator = GcovrReportinator.new( @ceedling )
      reportinators << reportinator
    end

    # Run reports using ReportGenerator
    if utility_enabled?( cfg_utils, UTILITY_NAME_REPORT_GENERATOR )
      reportinator = ReportGeneratorReportinator.new( @ceedling )
      reportinators << reportinator
    end

    return reportinators
  end

  # Returns true if the given utility is enabled, otherwise returns false.
  def utility_enabled?(opts, utility_name)
    enabled = !(opts.nil?) && (opts.map(&:upcase).include? utility_name.upcase)

    # Simple check for utility installation
    # system() result is nil if could not run command
    if enabled and system(utility_name, '--version', [:out, :err] => File::NULL).nil?
      @ceedling[:streaminator].stderr_puts("ERROR: gcov report generation tool '#{utility_name}'' not installed.", Verbosity::NORMAL)
      raise
    end

    return enabled
  end

end

# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash) if @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)
}
