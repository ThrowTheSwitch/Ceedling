# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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

    # Are any reports enabled?
    @reports_enabled = reports_enabled?( @project_config[:gcov_reports] )
    
    # Was a gcov: task on the command line?
    @cli_gcov_task = @ceedling[:system_wrapper].get_cmdline().any?{|item| item.include?( GCOV_TASK_ROOT )}

    # Validate the gcov tools if coverage summaries are enabled (summaries rely on the `gcov` tool)
    # Note: This gcov tool is a different configuration than the gcov tool used by ReportGenerator
    if summaries_enabled?( @project_config )
      @ceedling[:tool_validator].validate(
        tool: TOOLS_GCOV_SUMMARY,
        boom: true
      )
    end

    # Validate configuration and tools while building Reportinators
    @reportinators = build_reportinators( 
      @project_config[:gcov_utilities],
      @reports_enabled,
      @cli_gcov_task
    )

    # Convenient instance variable references
    @configurator = @ceedling[:configurator]
    @loginator = @ceedling[:loginator]
    @test_invoker = @ceedling[:test_invoker]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @file_path_utils = @ceedling[:file_path_utils]
    @file_wrapper = @ceedling[:file_wrapper]
    @tool_executor = @ceedling[:tool_executor]

    @mutex = Mutex.new()
  end

  # Called within class and also externally by plugin Rakefile
  # No parameters enables the opportunity for latter mechanism
  def automatic_reporting_enabled?
    return (@project_config[:gcov_report_task] == false)
  end

  def pre_compile_execute(arg_hash)
    if arg_hash[:context] == GCOV_SYM
      source = arg_hash[:source]

      # If a source file (not unity, mocks, etc.) is to be compiled use code coverage compiler
      if (File.extname(source) != EXTENSION_ASSEMBLY) && @configurator.collection_all_source.include?(source)
        arg_hash[:tool] = TOOLS_GCOV_COMPILER
        arg_hash[:msg] = "Compiling #{File.basename(source)} with coverage..."
      end
    end
  end

  def pre_link_execute(arg_hash)
    if arg_hash[:context] == GCOV_SYM
      arg_hash[:tool] = TOOLS_GCOV_LINKER
    end
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
    # Do nothing unless a gcov: task was on the command line
    return unless @cli_gcov_task

    # Only present plugin-based test results if raw test results disabled by a reporting plugin
    if !@configurator.plugins_display_raw_test_results
      results = {}

      # Assemble test results
      @mutex.synchronize do
        results = @plugin_reportinator.assemble_test_results( @result_list )
      end

      hash = {
        header: GCOV_ROOT_NAME.upcase,
        results: results
      }

      # Print unit test suite results
      @plugin_reportinator.run_test_results_report( hash ) do
        message = ''
        message = 'Unit test failures.' if results[:counts][:failed] > 0
        message
      end
    end

    # Print summary of coverage to console for each source file exercised by a test
    console_coverage_summaries() if summaries_enabled?( @project_config )

    # Run full coverage report generation
    generate_coverage_reports() if automatic_reporting_enabled?
  end

  # `Plugin` build step hook
  def summary
    # Only present plugin-based test results if raw test results disabled by a reporting plugin
    return if @configurator.plugins_display_raw_test_results

    # Build up the list of passing results from all tests
    result_list = @file_path_utils.form_pass_results_filelist(
      GCOV_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    hash = {
      header: GCOV_ROOT_NAME.upcase,
      # Collect all existing test results (success or failing) in the filesystem,
      # limited to our test collection
      :results => @plugin_reportinator.assemble_test_results(
        result_list,
        {:boom => false}
      )
    }

    @plugin_reportinator.run_test_results_report(hash)
  end

  # Called within class and also externally by conditionally regnerated Rake task
  # No parameters enables the opportunity for latter mechanism
  def generate_coverage_reports()
    return if not @reports_enabled

    @reportinators.each do |reportinator|
      # Create the artifacts output directory.
      @file_wrapper.mkdir( reportinator.artifacts_path )

      # Generate reports
      reportinator.generate_reports( @configurator.project_config_hash )
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
    banner = @plugin_reportinator.generate_banner( "#{GCOV_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @loginator.log "\n" + banner

    # Iterate over each test run and its list of source files
    @test_invoker.each_test_with_sources do |test, sources|
      heading = @plugin_reportinator.generate_heading( test )
      @loginator.log(heading)

      sources.each do |source|
        filename = File.basename(source)
        name     = filename.ext('')
        command  = @tool_executor.build_command_line(
                     TOOLS_GCOV_SUMMARY,
                     [], # No additional arguments
                     filename, # .c source file that should have been compiled with coverage
                     File.join(GCOV_BUILD_OUTPUT_PATH, test) # <build>/gcov/out/<test name> for coverage data files
                   )

        # Do not raise an exception if `gcov` terminates with a non-zero exit code, just note it and move on.
        # Recent releases of `gcov` have become more strict and vocal about errors and exit codes.
        command[:options][:boom] = false

        # Run the gcov tool and collect the raw coverage report
        shell_results  = @tool_executor.exec( command )
        results        = shell_results[:output].strip

        # Handle errors instead of raising a shell exception
        if shell_results[:exit_code] != 0
          debug = "gcov error (#{shell_results[:exit_code]}) while processing #{filename}... #{results}"
          @loginator.log( debug, Verbosity::DEBUG, LogLabels::ERROR )
          @loginator.log( "gcov was unable to process coverage for #{filename}", Verbosity::COMPLAIN )
          next # Skip to next loop iteration
        end

        # A source component may have been compiled with coverage but none of its code actually called in a test.
        # In this case, versions of gcov may not produce an error, only blank results.
        if results.empty?
          msg = "No functions called or code paths exercised by test for #{filename}"
          @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
          next # Skip to next loop iteration
        end

        # Source filepath to be extracted from gcov coverage results via regex
        _source = ''

        # Extract (relative) filepath from results and expand to absolute path
        matches = results.match(/File\s+'(.+)'/)
        if matches.nil? or matches.length() != 2
          msg = "Could not extract filepath via regex from gcov results for #{test}::#{File.basename(source)}"
          @loginator.log( msg, Verbosity::DEBUG, LogLabels::ERROR )
        else
          # Expand to full path from likely partial path to ensure correct matches on source component within gcov results
          _source = File.expand_path(matches[1])
        end

        # If gcov results include intended source (comparing absolute paths), report coverage details summaries
        if _source == File.expand_path(source)
          # Reformat from first line as filename banner to each line of statistics labeled with the filename
          # Only extract the first four lines of the console report (to avoid spidering coverage reports through libs, etc.)
          report = results.lines.to_a[1..4].map { |line| filename + ' | ' + line }.join('')
          @loginator.log(report + "\n")
        
        # Otherwise, found no coverage results
        else
          msg = "Found no coverage results for #{test}::#{File.basename(source)}"
          @loginator.log( msg, Verbosity::COMPLAIN )
        end
      end
    end
  end

  def build_reportinators(config, enabled, gcov_task)
    reportinators = []

    # Do not instantiate reportinators (and tool validation) unless reports enabled and a gcov: task present in command line
    return reportinators if ((!enabled) or (!gcov_task))

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

