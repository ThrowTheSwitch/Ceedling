# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'console_reportinator'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'

class Gcov < Plugin
  
  # `Plugin` setup()
  def setup
    @result_list = []
    @untested_sources = []

    @project_config = @ceedling[:configurator].project_config_hash

    # Check for a valid :untested_sources configuration value
    validate_untested_sources( @project_config )

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

    # #1252 -- Validate `:gcov ↳ :utilities` config (cheap, no external tool needed) and
    # build the console summary Reportinator (needs no external tool of its own) here,
    # eagerly, since `setup()` runs for every build this plugin is merely *enabled* for,
    # not only real `gcov:` builds. Deliberately NOT building the gcovr/ReportGenerator
    # Reportinators here -- doing so validates gcovr/ReportGenerator are installed
    # (see their own constructors), which would make either a hard dependency of any
    # build at all (e.g. plain `test:all`) rather than only a real `gcov:` build. See
    # generate_coverage_reports, which builds (and so validates) them lazily, only once
    # post_build already knows a gcov: task actually ran.
    validate_utilities_config( @project_config[:gcov_utilities] )
    @console_reportinator = summaries_enabled?( @project_config ) ?
      ConsoleReportinator.new( @ceedling, @project_config ) : nil
    @reportinators = nil

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
    @plugin_manager = @ceedling[:plugin_manager]

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

  # Called within class and also externally by plugin Rakefile to conditionally
  # create the standalone `gcov:untested_sources` task
  def untested_sources_compile_enabled?
    return (@project_config[:gcov_untested_sources] == GCOV_UNTESTED_SOURCES_COMPILE)
  end


  # guidance: — log actionable notice text when a `:compile` mode compilation fails.
  # Left `true` for a full build reached through plugin hooks (`gcov:all`, etc.), where
  # a failure may be unexpected. Set `false` by the standalone `gcov:untested_sources`
  # task, whose entire purpose is iterating on these failures directly at the compiler's
  # own error output, without Ceedling's added narrative repeating each run.
  def process_untested_sources(sources:, guidance: true)
    mode = @project_config[:gcov_untested_sources]

    case mode
    when GCOV_UNTESTED_SOURCES_IGNORE
      # Disabled entirely — no heading, no listing, no compilation, no log line at all.
      return

    when GCOV_UNTESTED_SOURCES_LIST
      msg = 'Processing Untested Sources'
      msg = @reportinator.generate_heading( @loginator.decorate( msg, LogLabels::RUN ) )
      @loginator.log( msg )

      untested_sources = collect_untested_sources( sources )
      # Retained for post_build's console reportinator, which still prints its own
      # (basename-keyed) "Untested Source Files" section from this same list.
      @untested_sources = untested_sources

      if untested_sources.empty?
        @loginator.log( 'No untested sources to process.' )
        return
      end

      # Full filepaths (not basenames)
      header = "Untested source files not in the coverage report (:untested_sources is :list):"
      @loginator.log_list( untested_sources.sort, header, Verbosity::COMPLAIN, LogLabels::WARNING )

    when GCOV_UNTESTED_SOURCES_COMPILE
      msg = 'Processing Untested Sources'
      msg = @reportinator.generate_heading( @loginator.decorate( msg, LogLabels::RUN ) )
      @loginator.log( msg )

      untested_sources = collect_untested_sources( sources )
      @untested_sources = untested_sources

      if untested_sources.empty?
        @loginator.log( 'No untested sources to process.' )
        return
      end

      untested_sources.each do |filepath|
        filename = File.basename(filepath)
        begin
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
        rescue ShellException => ex
          # Log actionable guidance then re-raise immediately (omitted when `guidance` is false)
          if guidance
            notice = "Compiling untested '#{filename}' with coverage failed.\n" \
                     "NOTE: Compilation of an untested source for coverage (:gcov ↳ :untested_sources ➡️ :compile) " \
                     "may require defines, flags, or platform symbols & headers not present in the test suite build.\n" \
                     "OPTIONS:\n" \
                     "  1) Provide needed compilation essentials using Ceedling features and/or code stand-ins.\n" \
                     "  2) Switch :gcov ↳ :untested_sources to :list to log untested files without compiling them.\n" \
                     "  3) Switch :gcov ↳ :untested_sources to :ignore to disable this feature entirely.\n" \
                     "See Gcov plugin docs for more explanation and recommendations.\n\n"
            @loginator.log( notice, Verbosity::COMPLAIN, LogLabels::NOTICE )
          end
          raise ex
        end
      end
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
  def post_build(_timestamp_s)
    # Do nothing unless a gcov: task was on the command line
    return unless @cli_gcov_task

    # Only present plugin-based test results if raw test results disabled by a reporting plugin
    if !@configurator.plugins_display_raw_test_results
      results = @plugin_reportinator.assemble_test_results( @result_list )
      hash = {
        context: GCOV_SYM,
        results: results
      }

      # #1251 -- `:warnings` on the CLI maps to Verbosity::COMPLAIN (see VERBOSITY_OPTIONS
      # in constants.rb), not NORMAL, so gating the all-clean case at NORMAL silently
      # swallowed the Overall Test Summary at --verbosity=warnings even on a passing run.
      verbosity = (results[:counts][:failed] > 0) ? Verbosity::ERRORS : Verbosity::COMPLAIN

      # Print unit test suite results
      @plugin_reportinator.run_test_results_report( hash, verbosity )
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
      context: GCOV_SYM,
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

    # #1252 -- Lazily build (and so validate the external tools of) the gcovr/
    # ReportGenerator Reportinators only now: this method only runs from post_build
    # (automatic reporting) or the standalone `gcov:report` task (manual reporting,
    # mutually exclusive with automatic per :gcov_report_task) -- either way, only
    # once a real gcov: task is confirmed to have already run. See setup()'s own
    # comment for why this can't happen any earlier. `||=` just guards against ever
    # rebuilding (and so re-validating) on a hypothetical repeat call.
    @reportinators ||= build_reportinators( @project_config[:gcov_utilities] )

    @reportinators.each do |reportinator|
      # Create the artifacts output directory.
      @file_wrapper.mkdir( reportinator.artifacts_path ) if reportinator.artifacts_path

      begin
        reportinator.generate_reports( @configurator.project_config_hash )
      rescue => ex
        # Register the exception as a build failure
        @ceedling[:plugin_manager].register_build_failure( GCOV_SYM, ex.message )
      end

      # Log summary set by reportinator during report generation (single logging site)
      unless reportinator.summary.empty?
        @loginator.log( @reportinator.generate_heading( "#{reportinator.name} Coverage Summary" ) )
        @loginator.log( reportinator.summary )
      end
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

  # Fail fast at plugin setup if :untested_sources holds anything other than a
  # recognized mode symbol (e.g. a leftover TRUE/FALSE from before this option
  # became an enum, or a typo'd symbol).
  def validate_untested_sources(config)
    value = config[:gcov_untested_sources]
    if not GCOV_UNTESTED_SOURCES_OPTIONS.include?( value )
      options = GCOV_UNTESTED_SOURCES_OPTIONS.map{ |opt| "':#{opt}'" }.join(', ')
      msg = "Plugin configuration :gcov ↳ :untested_sources ➡️ `#{value.inspect}` is not a recognized option {#{options}}."
      raise CeedlingException.new(msg)
    end
  end

  # All project sources minus every source any test references — works whether that
  # mapping came from a full test build (gcov:all) or a sources-only pass (gcov:untested_sources).
  def collect_untested_sources(sources)
    tested_sources = []
    @test_invoker.each_test_with_sources { |_, srcs| tested_sources.concat( srcs ) }
    return sources - tested_sources
  end

  # Fail fast at plugin setup if :utilities holds an unrecognized name (e.g. a typo) --
  # cheap, config-shape-only validation, so this stays eager even though the actual
  # Reportinators it names are built lazily (see build_reportinators, generate_coverage_reports).
  def validate_utilities_config(config)
    config.each do |reportinator|
      if not GCOV_UTILITY_NAMES.map(&:upcase).include?( reportinator.upcase )
        options = GCOV_UTILITY_NAMES.map{ |utility| "'#{utility}'" }.join(', ')
        msg = "Plugin configuration :gcov ↳ :utilities ➡️ `#{reportinator}` is not a recognized option {#{options}}."
        raise CeedlingException.new(msg)
      end
    end
  end

  # #1252 -- Deliberately not called from setup(); see its own comment and
  # generate_coverage_reports, the only caller. Constructing GcovrReportinator/
  # ReportGeneratorReportinator validates gcovr/ReportGenerator are installed, so this
  # can only run once a real gcov: task is confirmed to have run.
  def build_reportinators(config)
    reportinators = []

    # Run reports using gcovr
    if utility_enabled?( config, GCOV_UTILITY_NAME_GCOVR )
      reportinator = GcovrReportinator.new( @ceedling, @project_config )
      reportinators << reportinator
    end

    # Run reports using ReportGenerator
    if utility_enabled?( config, GCOV_UTILITY_NAME_REPORT_GENERATOR )
      reportinator = ReportGeneratorReportinator.new( @ceedling, @project_config )
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

    # First line of gcc --version: "gcc[.exe] (...platform info...) major.minor.patch"
    version_match = shell_result[:output].match(/^gcc(?:#{Regexp.escape(EXTENSION_WIN_EXE)})?\s+.*\s+(\d+)\.(\d+)\.\d+/)

    if version_match.nil? || version_match[1].nil? || version_match[2].nil?
      raise CeedlingException.new("Could not collect `gcc` version from its command line")
    end

    return GcovToolVersion.new( version_match[1].to_i, version_match[2].to_i )
  end

end

