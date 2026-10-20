# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'version'
require 'sanitize_constants'
require 'sanitize_config'
require 'sanitize_findings'
require 'sanitize_reports'
require 'sanitize_records'

# Builds and runs test executables with ASan, UBSan, and LeakSanitizer. A sanitize: build
# is instrumented, and ordinary test: builds are too when :test_builds asks. No other
# plugin's build is ever instrumented.
class Sanitize < Plugin

  # `Plugin` setup(). Checks only settings, since it runs for every command the plugin is
  # enabled for. The platform and tools are checked by validate_environment!.
  def setup
    @configurator        = @ceedling[:configurator]
    @loginator           = @ceedling[:loginator]
    @dependinator        = @ceedling[:dependinator]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @system_wrapper      = @ceedling[:system_wrapper]

    read_settings( @ceedling[:setupinator].config_hash[:sanitize] )

    @result_list = []
    @mutex       = Mutex.new
  end

  # Called by the plugin Rakefile's :sanitize_deps task, which every sanitize: task depends
  # on, so a project only enabling the plugin can still build where sanitizers can't run.
  # Memoized.
  def validate_environment!
    return if @environment_validated

    if @system_wrapper.windows?
      raise CeedlingException.new( "The sanitize plugin is not supported on Windows.\n" \
                                   "Remove `sanitize` from :plugins ↳ :enabled, or run sanitize: builds on Linux or macOS." )
    end

    @ceedling[:tool_validator].validate( tool: TOOLS_SANITIZE_FIXTURE, boom: true )
    @settings.notices.each { |notice| @loginator.log( notice, Verbosity::COMPLAIN ) }
    @environment_validated = true
  end

  # An instrumented test: build runs through no sanitize: task, so it checks here, once,
  # before any test builds
  def pre_test_build(context, _timestamp_s)
    validate_environment! if instrumented?( context )
  end

  def pre_test_compile_register(arg_hash)
    return unless instrumented?( arg_hash[:context] )
    return if EXTENSION_ASSEMBLY.match?( arg_hash[:source] )

    arg_hash[:flags] += @settings.compile_flags
    @dependinator.register( arg_hash[:object], meta: { sanitize: @build_settings } )
  end

  def pre_test_link_register(arg_hash)
    return unless instrumented?( arg_hash[:context] )

    arg_hash[:flags] += @settings.link_flags
    @dependinator.register( arg_hash[:executable], meta: { sanitize: @build_settings } )
  end

  # Runs the fixture tool, the project's own or Ceedling's, with each sanitizer's runtime
  # options set for it alone. Backtrace reruns go through it too, so they run the same way.
  def pre_test_fixture_register(arg_hash)
    return unless instrumented?( arg_hash[:context] )

    fixture = arg_hash[:tool]
    # Single-quoted, so the shell running the fixture command passes each value through as
    # written. A single quote within a value ends the quoting, is escaped, and resumes it.
    options = @settings.environment.map { |variable, value| "#{variable}='#{value.gsub( "'" ) { %q('\\'') }}'" }
    arguments = options + [fixture[:executable]] + Array( fixture[:arguments] )

    arg_hash[:tool] = TOOLS_SANITIZE_FIXTURE.merge( arguments: arguments, backtrace_rerun: true )
    @dependinator.register( arg_hash[:target], meta: { sanitize: @build_settings } )
  end

  # Findings come from the fixture's stderr, where every sanitizer reports. A test reported
  # from cached results was not run and has none.
  def post_test_fixture_execute(arg_hash)
    return unless instrumented?( arg_hash[:context] )
    return if arg_hash[:shell_result].nil?

    collect_result( arg_hash )

    findings = SanitizeFindings.parse( arg_hash[:shell_result][:stderr] )
    return if findings.empty?

    @records.record( arg_hash[:context], arg_hash[:test_name], findings )
  end

  # A crash a sanitizer stopped is named by its first finding. A backtrace rerun can reach a
  # finding the main run never did, so the findings it explains are recorded too.
  def explain_test_crash(arg_hash)
    return unless instrumented?( arg_hash[:context] )

    findings = SanitizeFindings.parse( arg_hash[:shell_result][:stderr] )
    return if findings.empty?

    @records.record( arg_hash[:context], arg_hash[:test_name], findings, explained: (findings.first if arg_hash[:crash_notice]) )
    arg_hash.merge!( SanitizeRecords.explanation( arg_hash[:context], arg_hash[:test_name], findings.first ) )
  end

  def post_build(_timestamp_s)
    contexts = reported_contexts
    return if contexts.empty?

    report_test_results if contexts.include?( SANITIZE_SYM )
    contexts.each { |context| @records.write_reports( context ) }

    @ceedling[:plugin_manager].register_build_failure( SANITIZE_SYM, @records.failure_message ) if @settings.fail_build && !@records.empty?
  end

  ### Private ###

  private

  # Only the settings that change what a build or test run produces are dependency meta, so
  # changing how findings are reported rebuilds nothing
  def read_settings(config)
    @build_settings = config.slice( :sanitizers, :recover, :detect_leaks, :runtime_options, :flags )
    @settings = SanitizeConfig.new( config, platform: platform )

    reports  = SanitizeReports.load( config[:reports], version: Ceedling::Version::TAG )
    @records = SanitizeRecords.new( file_wrapper: @ceedling[:file_wrapper], loginator: @loginator, reports: reports )
  end

  def platform
    return :windows if @system_wrapper.windows?
    return :macos   if @system_wrapper.macos?

    return :linux
  end

  def instrumented?(context)
    return context == SANITIZE_SYM || (@settings.test_builds && context == TEST_SYM)
  end

  # A sanitize: build reports its own test results, apart from an ordinary test build's
  def collect_result(arg_hash)
    return unless arg_hash[:context] == SANITIZE_SYM

    @mutex.synchronize { @result_list << arg_hash[:result_file] unless @result_list.include?( arg_hash[:result_file] ) }
  end

  # The instrumented builds this run included
  def reported_contexts
    contexts = []
    contexts << SANITIZE_SYM if @ceedling[:rake_invocation_tracker].invoked?( /^#{SANITIZE_ROOT_NAME}(:|$)/ )
    contexts << TEST_SYM if @settings.test_builds && @ceedling[:rake_invocation_tracker].invoked?( /^test(:|$)/ )
    return contexts
  end

  # Only when a reporting plugin has disabled raw test results display
  def report_test_results
    return if @configurator.plugins_display_raw_test_results

    results = @plugin_reportinator.assemble_test_results( @result_list )
    @plugin_reportinator.run_test_results_report( { context: SANITIZE_SYM, results: results }, @plugin_reportinator.test_results_floor_verbosity )
  end

end
