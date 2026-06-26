# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'gcov_constants'
require 'gcov_types'
require 'console_reportinator'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'

class Gcov < Plugin
  
  # `Plugin` setup()
  def setup
    @result_list = []
    @untested_sources = []

    @project_config = @ceedling[:configurator].project_config_hash

    # Are any reports enabled?
    @reports_enabled = reports_enabled?( @project_config[:gcov_reports] )
    @cli_gcov_task = false

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
      @reports_enabled
    )

    # Convenient instance variable references
    @configurator = @ceedling[:configurator]
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
    @test_invoker = @ceedling[:test_invoker]
    @flaginator = @ceedling[:flaginator]
    @defineinator = @ceedling[:defineinator]
    @generator = @ceedling[:generator]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @file_path_utils = @ceedling[:file_path_utils]
    @file_wrapper = @ceedling[:file_wrapper]
    @tool_executor = @ceedling[:tool_executor]

    @mutex = Mutex.new()

    # Validate MC/DC configuration against GCC version (only incurs gcc --version when :mcdc: TRUE)
    if @project_config[:gcov_mcdc]
      gcc_version = get_gcc_version()
      if gcc_version.major < 14
        raise CeedlingException.new(
          ":gcov ↳ :mcdc ➡️ Modified condition/decision coverage requires GCC 14 or higher " \
          "(found #{gcc_version.major}.#{gcc_version.minor})"
        )
      end
    end
  end

  # Called within class and also externally by plugin Rakefile
  # No parameters enables the opportunity for latter mechanism
  def automatic_reporting_enabled?
    return (@project_config[:gcov_report_task] == false)
  end


  def process_untested_sources(sources:)
    unless @project_config[:gcov_untested_sources]
      msg = 'Skipping code coverage processing of untested sources'
      @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
      return
    end

    msg = 'Processing Untested Sources'
    msg = @reportinator.generate_heading( @loginator.decorate( msg, LogLabels::RUN ) )
    @loginator.log( msg )

    tested_sources = []
    @test_invoker.each_test_with_sources { |_, srcs| tested_sources.concat( srcs ) }
    untested_sources = sources - tested_sources

    @untested_sources = untested_sources

    if untested_sources.empty?
      @loginator.log( 'No untested sources to process.' )
      return
    end

    untested_sources.each do |filepath|
      filename = File.basename(filepath)
      @generator.generate_object_file_c(
        tool:         TOOLS_GCOV_COMPILER,
        module_name:  filename.ext(),
        context:      GCOV_SYM,
        source:       filepath,
        object:       @file_path_utils.form_test_object_filepath( filepath, context:GCOV_SYM ),
        search_paths: @configurator.collection_paths_include,
        flags:        @flaginator.flag_down( context:GCOV_SYM, operation:OPERATION_COMPILE_SYM ),
        defines:      @defineinator.defines( subkey:GCOV_SYM ),
        dependencies: @file_path_utils.form_test_dependencies_filepath( filepath, context:GCOV_SYM )
      )
    end
  end

  def pre_compile_execute(arg_hash)
    if arg_hash[:context] == GCOV_SYM
      source = arg_hash[:source]

      # Compile all non-assembly files with coverage; gcovr --exclude filters non-production files from reports
      if File.extname(source) != EXTENSION_ASSEMBLY
        arg_hash[:tool] = TOOLS_GCOV_COMPILER
        arg_hash[:msg] = @reportinator.generate_module_progress(
          operation: "Compiling with coverage",
          module_name: arg_hash[:module_name],
          filename: File.basename(source)
        )
        arg_hash[:flags] += ['-fcondition-coverage'] if @project_config[:gcov_mcdc]
      end
    end
  end

  def pre_link_execute(arg_hash)
    if arg_hash[:context] == GCOV_SYM
      @cli_gcov_task = true
      arg_hash[:tool] = TOOLS_GCOV_LINKER
      arg_hash[:flags] += ['-fcondition-coverage'] if @project_config[:gcov_mcdc]
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

    # Print summary of coverage to console for each source file exercised by a test,
    # plus a final section for any source files not exercised by any test.
    @console_reportinator&.generate_reports( @project_config, untested_sources: @untested_sources )

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
      @file_wrapper.mkdir( reportinator.artifacts_path ) if reportinator.artifacts_path

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

  def build_reportinators(config, enabled)
    reportinators = []

    # Instantiate console summary reportinator if summaries enabled
    @console_reportinator = summaries_enabled?(@project_config) ?
      ConsoleReportinator.new(@ceedling) : nil

    # Do not instantiate file reportinators (and tool validation) unless reports enabled
    return reportinators if (!enabled)

    config.each do |reportinator|
      if not GCOV_UTILITY_NAMES.map(&:upcase).include?( reportinator.upcase )
        options = GCOV_UTILITY_NAMES.map{ |utility| "'#{utility}'" }.join(', ')
        msg = "Plugin configuration :gcov ↳ :utilities ➡️ `#{reportinator}` is not a recognized option {#{options}}."
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

  def get_gcc_version()
    command = @tool_executor.build_command_line( TOOLS_GCOV_GCC_VERSION, [])

    @loginator.lazy( Verbosity::OBNOXIOUS ) do
      @reportinator.generate_progress("Collecting GCC version for conditional feature handling")
    end

    shell_result = @tool_executor.exec( command )

    # First line of gcc --version: "gcc (...platform info...) major.minor.patch"
    version_match = shell_result[:output].match(/^gcc\s+.*\s+(\d+)\.(\d+)\.\d+/)

    if version_match.nil? || version_match[1].nil? || version_match[2].nil?
      raise CeedlingException.new("Could not collect `gcc` version from its command line")
    end

    return GcovToolVersion.new( version_match[1].to_i, version_match[2].to_i )
  end

end

