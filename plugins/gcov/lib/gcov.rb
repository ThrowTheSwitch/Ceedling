require 'ceedling/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'gcov_constants'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'

class Gcov < Plugin
  
  # `Plugin` setup()
  def setup
    @result_list = []

    @project_config = @ceedling[:configurator].project_config_hash
    @reports_enabled = reports_enabled?( @project_config[:gcov_reports] )

    # Validate the gcov tools if coverage summaries are enabled (summaries rely on the gcov tool)
    # Note: This gcov tool is a different configuration than the gcov tool used by ReportGenerator
    if summaries_enabled?( @project_config )
      @ceedling[:tool_validator].validate(
        tool: TOOLS_GCOV_SUMMARY,
        extension: EXTENSION_EXECUTABLE,
        boom: true
      )
    end

    # Validate tools and configuration while building reportinators
    @reportinators = build_reportinators( @project_config[:gcov_utilities], @reports_enabled )

    @mutex = Mutex.new()
  end

  # Called within class and also externally by plugin Rakefile
  # No parameters enables the opportunity for latter mechanism
  def automatic_reporting_enabled?
    return (@project_config[:gcov_report_task] == false)
  end

  def generate_coverage_object_file(test, source, object)
    # Non-coverage compiler
    tool = TOOLS_TEST_COMPILER
    msg = nil

    # Handle assembly file that comes through
    if File.extname(source) == EXTENSION_ASSEMBLY
      tool = TOOLS_TEST_ASSEMBLER
    # If a source file (not unity, mocks, etc.) is to be compiled use code coverage compiler
    elsif @ceedling[:configurator].collection_all_source.include?(source)
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

  # `Plugin` build step hook
  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    @mutex.synchronize do
      if (result_file =~ /#{GCOV_RESULTS_PATH}/) && !@result_list.include?(result_file)
        @result_list << arg_hash[:result_file]
      end
    end
  end

  # `Plugin` build step hook
  def post_build
    # Do nothing unless a gcov: task was used
    return unless @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)

    results = {}

    # Assemble test results
    @mutex.synchronize do
      results = @ceedling[:plugin_reportinator].assemble_test_results( @result_list )
    end

    hash = {
      header: GCOV_ROOT_NAME.upcase,
      results: results
    }

    # Print unit test suite results
    @ceedling[:plugin_reportinator].run_test_results_report( hash ) do
      message = ''
      message = 'Unit test failures.' if results[:counts][:failed] > 0
      message
    end

    # Print summary of coverage to console for each source file exercised by a test
    console_coverage_summaries() if summaries_enabled?( @project_config )

    # Run full coverage report generation
    generate_coverage_reports() if automatic_reporting_enabled?
  end

  # `Plugin` build step hook
  def summary
    # Build up the list of passing results from all tests
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(
      GCOV_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    hash = {
      header: GCOV_ROOT_NAME.upcase,
      # Collect all existing test results (success or failing) in the filesystem,
      # limited to our test collection
      :results => @ceedling[:plugin_reportinator].assemble_test_results(
        result_list,
        {:boom => false}
      )
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
  end

  # Called within class and also externally by conditionally regnerated Rake task
  # No parameters enables the opportunity for latter mechanism
  def generate_coverage_reports()
    return if not @reports_enabled

    @reportinators.each do |reportinator|
      # Create the artifacts output directory.
      @ceedling[:file_wrapper].mkdir( reportinator.artifacts_path )

      # Generate reports
      reportinator.generate_reports( @ceedling[:configurator].project_config_hash )
    end
  end

  ### Private ###

  private

  def reports_enabled?(cfg_reports)
    return !cfg_reports.empty?
  end

  def summaries_enabled?(config)
    return config[:gcov_summaries]
  end

  def utility_enabled?(opts, utility_name)
    return opts.map(&:upcase).include?( utility_name.upcase )
  end

  def console_coverage_summaries()
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
                     TOOLS_GCOV_SUMMARY,
                     [], # No additional arguments
                     filename, # .c source file that should have been compiled with coverage
                     File.join(GCOV_BUILD_OUTPUT_PATH, test) # <build>/gcov/out/<test name> for coverage data files
                   )

        # Do not raise an exception if `gcov` terminates with a non-zero exit code, just note it and move on.
        # Recent releases of `gcov` have become more strict and vocal about errors and exit codes.
        command[:options][:boom] = false

        # Run the gcov tool and collect the raw coverage report
        shell_results  = @ceedling[:tool_executor].exec( command )
        results        = shell_results[:output].strip

        # Handle errors instead of raising a shell exception
        if shell_results[:exit_code] != 0
          debug = "ERROR: gcov error (#{shell_results[:exit_code]}) while processing #{filename}... #{results}"
          @ceedling[:streaminator].stderr_puts(debug, Verbosity::DEBUG)
          @ceedling[:streaminator].stderr_puts("WARNING: gcov was unable to process coverage for #{filename}\n", Verbosity::COMPLAIN)
          next # Skip to next loop iteration
        end

        # A source component may have been compiled with coverage but none of its code actually called in a test.
        # In this case, versions of gcov may not produce an error, only blank results.
        if results.empty?
          @ceedling[:streaminator].stdout_puts("NOTICE: No functions called or code paths exercised by test for #{filename}\n", Verbosity::COMPLAIN)
          next # Skip to next loop iteration
        end

        # Source filepath to be extracted from gcov coverage results via regex
        _source = ''

        # Extract (relative) filepath from results and expand to absolute path
        matches = results.match(/File\s+'(.+)'/)
        if matches.nil? or matches.length() != 2
          msg = "ERROR: Could not extract filepath via regex from gcov results for #{test}::#{File.basename(source)}"
          @ceedling[:streaminator].stderr_puts( msg, Verbosity::DEBUG )
        else
          # Expand to full path from likely partial path to ensure correct matches on source component within gcov results
          _source = File.expand_path(matches[1])
        end

        # If gcov results include intended source (comparing absolute paths), report coverage details summaries
        if _source == File.expand_path(source)
          # Reformat from first line as filename banner to each line of statistics labeled with the filename
          # Only extract the first four lines of the console report (to avoid spidering coverage reports through libs, etc.)
          report = results.lines.to_a[1..4].map { |line| filename + ' | ' + line }.join('')
          @ceedling[:streaminator].stdout_puts(report + "\n")
        
        # Otherwise, found no coverage results
        else
          msg = "WARNING: Found no coverage results for #{test}::#{File.basename(source)}\n"
          @ceedling[:streaminator].stderr_puts( msg, Verbosity::COMPLAIN )
        end
      end
    end
  end

  def build_reportinators(config, enabled)
    reportinators = []

    return reportinators if not enabled

    config.each do |reportinator|
      if not GCOV_UTILITY_NAMES.map(&:upcase).include?( reportinator.upcase )
        options = GCOV_UTILITY_NAMES.map{ |utility| "'#{utility}'" }.join(', ')
        msg = "Plugin configuration :gcov ↳ :utilities => `#{reportinator}` is not a recognized option {#{options}}."
        raise CeedlingException.new(msg)
      end
    end

    # Run reports using gcovr
    if utility_enabled?( config, GCOV_UTILITY_NAME_GCOVR )
      reportinator = GcovrReportinator.new( @ceedling )
      reportinators << reportinator
    end

    # Run reports using ReportGenerator
    if utility_enabled?( config, GCOV_UTILITY_NAME_REPORT_GENERATOR )
      reportinator = ReportGeneratorReportinator.new( @ceedling )
      reportinators << reportinator
    end

    return reportinators
  end

end

# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash) if @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)
}
