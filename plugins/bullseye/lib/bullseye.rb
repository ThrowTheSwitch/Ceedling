# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'csv'
require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'bullseye_constants'

# Integrates Bullseye code coverage into Ceedling test builds. Coverage instrumentation
# is not driven by any Rake rule this plugin defines — Ceedling's core build pipeline
# always compiles and links every test build itself, firing `pre_compile_execute`/
# `pre_link_execute` hooks that this class uses to swap in Bullseye's `covc`-wrapped
# compiler/linker and add coverage-specific defines for the `bullseye:` task context
# only. See `plugins/gcov/lib/gcov.rb` for the same pattern applied to a different
# coverage toolchain.
class Bullseye < Plugin

  def setup
    @result_list = []
    @cli_bullseye_task = false

    @project_config = @ceedling[:configurator].project_config_hash

    # Validate enumerated configuration values. Failing here is fast and specific.
    # Deferring to report time would surface a mistake as a skipped feature.
    validate_untested_sources( @project_config )
    validate_branch_detail( @project_config )
    validate_xml_report( @project_config )

    # COVFILE environment variable — collected by PluginManager across all plugins, flattened
    # into the ENVIRONMENT_COVFILE global constant and the real COVFILE env var by Configurator
    @environment = [ {:covfile => BULLSEYE_COVFILE_PATH} ]

    # COVLM environment variable — only meaningful for Bullseye's floating/evaluation
    # license scheme (a shared license manager file consulted by every Bullseye tool
    # invocation). Node-locked/unlimited licenses are activated once, at installation,
    # independent of any per-build environment variable, so this option is a no-op for
    # those and is left unset by default.
    license_manager_file = @project_config[:bullseye_license_manager_file]
    @environment << {:covlm => license_manager_file} unless license_manager_file.nil?

    @coverage_template_all = @ceedling[:file_wrapper].read( File.join( @plugin_root_path, 'assets/template.erb' ) )

    # Convenient instance variable references
    @configurator        = @ceedling[:configurator]
    @loginator           = @ceedling[:loginator]
    @reportinator        = @ceedling[:reportinator]
    @test_invoker        = @ceedling[:test_invoker]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @tool_executor       = @ceedling[:tool_executor]
    @file_wrapper        = @ceedling[:file_wrapper]

    @mutex = Mutex.new()

    # Compiler/linker are non-optional — validate up front (report tools are validated lazily,
    # immediately before each is actually invoked, since they may never be used)
    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_COMPILER, boom: true )
    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_LINKER, boom: true )
  end

  # Swaps in the covc-wrapped compiler (and the coverage define) ahead of
  # TestBuildExecutor's own dependency-tracker meta capture, so a change to either is
  # what actually invalidates a bullseye-context object's cache -- not the plain test
  # compiler this replaces. Instrument every non-assembly file uniformly; report-time
  # exclusions (covselect) filter framework/test noise rather than skipping
  # instrumentation at compile time.
  def pre_test_compile_register(arg_hash)
    return if (arg_hash[:context] != BULLSEYE_SYM)
    return if EXTENSION_ASSEMBLY.match?(arg_hash[:source])

    arg_hash[:tool] = TOOLS_BULLSEYE_COMPILER
    arg_hash[:defines] += ['CODE_COVERAGE']
  end

  def pre_compile_execute(arg_hash)
    return if (arg_hash[:context] != BULLSEYE_SYM)
    return if EXTENSION_ASSEMBLY.match?(arg_hash[:source])

    arg_hash[:msg] = @reportinator.generate_module_progress(
      operation: "Compiling with coverage",
      module_name: arg_hash[:module_name],
      filename: File.basename(arg_hash[:source])
    )
  end

  # As pre_test_compile_register above, for the covlink-wrapped linker. Fires every run
  # regardless of whether this executable actually needs relinking, which is also what
  # lets post_build's summary print correctly even on a fully-cached bullseye:all
  # re-run -- @cli_bullseye_task marks that a bullseye: task ran at all, not that a
  # link did.
  def pre_test_link_register(arg_hash)
    return if (arg_hash[:context] != BULLSEYE_SYM)

    @cli_bullseye_task = true
    arg_hash[:tool] = TOOLS_BULLSEYE_LINKER
  end

  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    @mutex.synchronize do
      # #104 -- `[`/`]` are legal filename characters, but also regex character-class
      # syntax; interpolating BULLSEYE_RESULTS_PATH into this regex unescaped means a
      # literal bracket anywhere in it (e.g. a bracket-containing :build_root:) silently
      # breaks this match, and the test never gets counted here.
      if ((result_file =~ /#{Regexp.escape(BULLSEYE_RESULTS_PATH)}/) and (not @result_list.include?(result_file)))
        @result_list << result_file
      end
    end
  end

  def post_build(_timestamp_s)
    return if (not @cli_bullseye_task)

    # test results
    if !@configurator.plugins_display_raw_test_results
      results = @plugin_reportinator.assemble_test_results(@result_list)
      hash = {
        :context => BULLSEYE_SYM,
        :results => results
      }

      verbosity = @plugin_reportinator.test_results_floor_verbosity
      @plugin_reportinator.run_test_results_report(hash, verbosity)
    end

    # coverage results
    return if (verify_coverage_file() == false)

    # covselect exclusions must be applied regardless of :summaries — covhtml honors
    # the same persisted selections, so this isn't just a console-output concern
    apply_report_exclusions()

    # Totals are collected once. The console summary and the coverage threshold check
    # both consume them. Collection is skipped when neither one needs them.
    totals = nil
    totals = collect_coverage_totals() if summaries_enabled? or thresholds_configured?

    if summaries_enabled?
      report_per_function_coverage_results()
      report_coverage_results_all( totals )
    end

    report_branch_coverage_results()

    if automatic_reporting_enabled?
      generate_html_report()
      generate_xml_report()
    end

    # Runs last so the developer sees every report before the build fails.
    enforce_coverage_thresholds( totals )
  end

  def summary
    return if (verify_coverage_file() == false)
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist( BULLSEYE_RESULTS_PATH, COLLECTION_ALL_TESTS )

    # test results
    # get test results for only those tests in our configuration and of those only tests with results on disk
    hash = {
      :context => BULLSEYE_SYM,
      :results => @plugin_reportinator.assemble_test_results(result_list, {:boom => false})
    }

    @plugin_reportinator.run_test_results_report(hash)

    # coverage results
    report_coverage_results_all( collect_coverage_totals() ) if summaries_enabled?
  end

  # Called within class and also externally by plugin Rakefile
  # No parameters enables the opportunity for latter mechanism
  # Gates both the HTML and XML reports. A dedicated report task and automatic
  # report generation are mutually exclusive.
  def automatic_reporting_enabled?
    return (@project_config[:bullseye_report_task] == false)
  end

  def summaries_enabled?
    return (@project_config[:bullseye_summaries] != false)
  end

  # Called within class and also externally by plugin Rakefile to conditionally
  # create the standalone `bullseye:untested_sources` task
  def untested_sources_compile_enabled?
    return (@project_config[:bullseye_untested_sources] == BULLSEYE_UNTESTED_SOURCES_COMPILE)
  end

  # guidance: — log actionable notice text when a `:compile` mode compilation fails.
  # Left `true` for a full build reached through plugin hooks (`bullseye:all`, etc.), where
  # a failure may be unexpected. Set `false` by the standalone `bullseye:untested_sources`
  # task, whose entire purpose is iterating on these failures directly at the compiler's
  # own error output, without Ceedling's added narrative repeating each run.
  def process_untested_sources(sources:, guidance: true)
    mode = @project_config[:bullseye_untested_sources]

    case mode
    when BULLSEYE_UNTESTED_SOURCES_IGNORE
      return

    when BULLSEYE_UNTESTED_SOURCES_LIST
      untested_sources = collect_untested_sources( sources )

      if untested_sources.empty?
        @loginator.log( 'No untested sources to process.' )
        return
      end

      header = "Untested source files not in the coverage report (:untested_sources is :list):"
      @loginator.log_list( untested_sources.sort, header, Verbosity::COMPLAIN, LogLabels::WARNING )

    when BULLSEYE_UNTESTED_SOURCES_COMPILE
      untested_sources = collect_untested_sources( sources )

      if untested_sources.empty?
        @loginator.log( 'No untested sources to process.' )
        return
      end

      dependinator = @ceedling[:dependinator]
      skipped = 0

      untested_sources.each do |filepath|
        filename     = File.basename(filepath)
        object       = @ceedling[:file_path_utils].form_test_object_filepath( filepath, context: BULLSEYE_SYM )
        dependencies = @ceedling[:file_path_utils].form_test_dependencies_filepath( filepath, context: BULLSEYE_SYM )
        search_paths = @configurator.collection_paths_include
        flags        = @ceedling[:flaginator].flag_down( context: BULLSEYE_SYM, operation: OPERATION_COMPILE_SYM )
        defines      = @ceedling[:defineinator].defines( subkey: BULLSEYE_SYM )

        # Same register/stale?/mark_fresh idiom TestBuildExecutor's own object
        # compilation uses -- this compile happens entirely outside that pipeline
        # (untested sources have no test of their own to drive them through it), so
        # nothing else registers it.
        dependinator.register(
          object, files: [filepath],
          meta: { flags: flags, defines: defines, search_paths: search_paths, tools: [TOOLS_BULLSEYE_COMPILER] }
        )
        dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )

        unless dependinator.stale?( object )
          msg = @reportinator.generate_module_progress(
            operation:   'Skipping untested-source compilation for',
            module_name: filename.ext(),
            filename:    filename
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )
          skipped += 1
          next
        end

        begin
          @ceedling[:generator].generate_object_file_c(
            tool:         TOOLS_BULLSEYE_COMPILER,
            module_name:  filename.ext(),
            context:      BULLSEYE_SYM,
            source:       filepath,
            object:       object,
            search_paths: search_paths,
            flags:        flags,
            # 'CODE_COVERAGE' is not added here — pre_compile_execute appends it for every
            # BULLSEYE_SYM-context compile, including this one (generate_object_file_c fires
            # that hook itself); adding it here too would just duplicate the define.
            defines:      defines,
            dependencies: dependencies
          )

          dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
          dependinator.mark_fresh( object )
        rescue ShellException => ex
          if guidance
            notice = "Compiling untested '#{filename}' with coverage failed.\n" \
                     "NOTE: Compilation of an untested source for coverage (:bullseye ↳ :untested_sources ➡️ :compile) " \
                     "may require defines, flags, or platform symbols & headers not present in the test suite build.\n" \
                     "OPTIONS:\n" \
                     "  1) Provide needed compilation essentials using Ceedling features and/or code stand-ins.\n" \
                     "  2) Switch :bullseye ↳ :untested_sources to :list to log untested files without compiling them.\n" \
                     "  3) Switch :bullseye ↳ :untested_sources to :ignore to disable this feature entirely.\n\n"
            @loginator.log( notice, Verbosity::COMPLAIN, LogLabels::NOTICE )
          end
          raise ex
        end
      end

      # TestInvoker's own flush (test_invoker.rb) already ran and persisted by the
      # time this method runs (see bullseye.rake -- this is always called after
      # setup_and_invoke returns) -- this flush persists the additional entries
      # registered above on top of that, safely: flush doesn't clear in-memory
      # state, so this just writes out the superset to the same already-open cache.
      dependinator.flush( refresh_dependencies: false )

      msg = @reportinator.generate_skip_summary( task: "compilation", count: skipped, noun: "untested sources" )
      @loginator.log( msg ) unless msg.nil?
    end
  end

  # Generates a full interactive HTML coverage report to the artifacts directory.
  # Called within class and also externally by plugin Rakefile (report:bullseye / post_build).
  def generate_html_report()
    begin
      @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVHTML, boom: true )

      @file_wrapper.mkdir( BULLSEYE_HTML_ARTIFACTS_PATH ) unless @file_wrapper.exist?( BULLSEYE_HTML_ARTIFACTS_PATH )

      command = @tool_executor.build_command_line(TOOLS_BULLSEYE_REPORT_COVHTML, [], BULLSEYE_HTML_ARTIFACTS_PATH)
      @tool_executor.exec( command )

      @loginator.log( "Bullseye HTML coverage report: #{BULLSEYE_HTML_ARTIFACTS_PATH}" )
    rescue => ex
      @ceedling[:plugin_manager].register_build_failure( BULLSEYE_SYM, license_guidance( ex.message ) )
    end
  end

  # Generates a machine-readable coverage report for CI tooling.
  # Called within class and also externally by plugin Rakefile (report:bullseye / post_build).
  # Does nothing unless :xml_report names a format.
  def generate_xml_report()
    format = @project_config[:bullseye_xml_report]
    return if format == BULLSEYE_XML_REPORT_NONE

    begin
      @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVXML, boom: true )

      @file_wrapper.mkdir( BULLSEYE_ARTIFACTS_PATH ) unless @file_wrapper.exist?( BULLSEYE_ARTIFACTS_PATH )

      command = @tool_executor.build_command_line(
        TOOLS_BULLSEYE_REPORT_COVXML, [],
        BULLSEYE_XML_REPORT_FLAGS[format],
        BULLSEYE_XML_ARTIFACT_PATH
      )
      @tool_executor.exec( command )

      @loginator.log( "Bullseye #{format} XML coverage report: #{BULLSEYE_XML_ARTIFACT_PATH}" )
    rescue => ex
      @ceedling[:plugin_manager].register_build_failure( BULLSEYE_SYM, license_guidance( ex.message ) )
    end
  end

  # Reports Bullseye license status to the console.
  # Called externally by plugin Rakefile (utils:bullseye_license).
  #
  # covlmgr reports the license number and expiry date in its banner for every
  # license type. It then reports license manager utilization. An unlimited license
  # cannot use the license manager at all. "License manager disabled" is therefore
  # the expected result for one, not a problem to report.
  def report_license_status()
    begin
      @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_LICENSE_STATUS, boom: true )

      command      = @tool_executor.build_command_line( TOOLS_BULLSEYE_LICENSE_STATUS, [] )
      shell_result = @tool_executor.exec( command )

      banner = @plugin_reportinator.generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: LICENSE STATUS" )
      @loginator.log "\n" + banner + shell_result[:output].to_s.strip + "\n\n"
    rescue => ex
      @ceedling[:plugin_manager].register_build_failure( BULLSEYE_SYM, ex.message )
    end
  end

  private ###################################

  def validate_untested_sources(config)
    validate_enumerated_option( config, :bullseye_untested_sources, ':untested_sources', BULLSEYE_UNTESTED_SOURCES_OPTIONS )
  end

  def validate_branch_detail(config)
    validate_enumerated_option( config, :bullseye_branch_detail, ':branch_detail', BULLSEYE_BRANCH_DETAIL_OPTIONS )
  end

  def validate_xml_report(config)
    validate_enumerated_option( config, :bullseye_xml_report, ':xml_report', BULLSEYE_XML_REPORT_OPTIONS )
  end

  # Rejects an unrecognized value for any enumerated plugin setting.
  # Raising at setup names the offending setting directly. Deferring to report time
  # would surface the mistake as a silently skipped feature instead.
  def validate_enumerated_option(config, key, label, options)
    value = config[key]
    return if options.include?( value )

    list = options.map{ |opt| "':#{opt}'" }.join(', ')
    msg = "Plugin configuration :bullseye ↳ #{label} ➡️ `#{value.inspect}` is not a recognized option {#{list}}."
    raise CeedlingException.new(msg)
  end

  # An unlicensed or expired Bullseye installation surfaces only as an opaque failure
  # from the tool itself. Naming the license diagnostic turns that into a next step.
  def license_guidance(message)
    return "#{message}\n" \
           "NOTE: Bullseye tools also fail this way when no valid license is available.\n" \
           "Run `ceedling utils:bullseye_license` to report Bullseye license status.\n\n"
  end

  # All project sources minus every source any test references
  def collect_untested_sources(sources)
    tested_sources = []
    @test_invoker.each_test_with_sources { |_, srcs| tested_sources.concat( srcs ) }
    return sources - tested_sources
  end

  # Applies report-time exclusions (framework/test sources) via covselect, independent
  # of the coverage data itself. Both covsrc (report_coverage_results_all) and covhtml
  # (generate_html_report) automatically honor these persisted selections with no
  # further arguments needed on their own invocations. covfn's per-function loop
  # (report_per_function_coverage_results) filters its own source list in Ruby instead,
  # since it iterates one already-selected source at a time rather than reporting
  # against the whole coverage file.
  #
  # Bullseye records each source's path in the .cov file relative to the .cov file's
  # own directory, and these exclusion patterns match against that raw stored path.
  # BULLSEYE_COVFILE_PATH is therefore kept at project root (see bullseye_constants.rb)
  # rather than under build/ like this plugin's other artifacts — project root is the
  # only location that is a common ancestor of every possible source directory
  # (src/, test/, build/vendor/.../, build/test/runners/, etc.), so patterns like
  # `!**/unity.c` match regardless of how deeply nested the actual source file is.
  def apply_report_exclusions()
    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_COVSELECT, boom: false, respect_optional: true )

    # A source extension can be configured as more than one string, so each ignored
    # name/prefix contributes one covselect exclusion pattern per configured extension.
    patterns = BULLSEYE_IGNORE_SOURCES.flat_map { |name| EXTENSION_SOURCE.map { |ext| "!**/#{name}#{ext}" } }
    patterns += EXTENSION_SOURCE.map { |ext| "!**/#{@configurator.project_test_file_prefix}*#{ext}" }
    patterns += EXTENSION_SOURCE.map { |ext| "!**/#{@configurator.cmock_mock_prefix}*#{ext}" }

    patterns.each do |pattern|
      command = @tool_executor.build_command_line(TOOLS_BULLSEYE_COVSELECT, [], pattern)
      command[:options][:boom] = false
      @tool_executor.exec( command )
    end
  end

  # Runs covsrc and returns whole-project coverage percentages.
  #
  # No region arguments are passed. covsrc reports against the whole coverage file.
  # It honors whatever exclusions apply_report_exclusions already registered through
  # covselect.
  #
  # The tool is configured for `--csv`. Its final row carries the project total.
  # The columns are source, function covered, function total, function percent,
  # condition/decision covered, condition/decision total, condition/decision percent.
  def collect_coverage_totals()
    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVSRC, boom: false, respect_optional: true )

    command      = @tool_executor.build_command_line(TOOLS_BULLSEYE_REPORT_COVSRC, [])
    shell_result = @tool_executor.exec( command )

    totals = { :functions => nil, :branches => nil }

    # Tool output is an external boundary. Malformed rows yield no totals rather
    # than aborting a build whose tests already ran and passed.
    begin
      CSV.parse( shell_result[:output] ) do |row|
        next if row.nil? or (row[0] != 'Total')
        totals[:functions] = extract_coverage_percentage( row[3] )
        totals[:branches]  = extract_coverage_percentage( row[6] )
      end
    rescue CSV::MalformedCSVError
      @loginator.log( 'Could not parse Bullseye coverage totals from covsrc.', Verbosity::COMPLAIN )
    end

    return totals
  end

  # covsrc renders a CSV percentage as digits followed by '%'. A source with no
  # measurable probes yields an empty field instead of a percentage.
  def extract_coverage_percentage(field)
    match = field.to_s.match( /(\d+)\s*%/ )
    return nil if match.nil?
    return match[1].to_i
  end

  def report_coverage_results_all(totals)
    results = {
      :context  => BULLSEYE_SYM,
      :coverage => totals
    }

    @plugin_reportinator.run_report( @coverage_template_all, results )
  end

  # Prints an annotated source listing identifying individual uncovered branches.
  # covsrc and covfn report branch coverage only as a percentage. This is the one
  # console report naming the branches behind that number.
  #
  # Invoked once against the whole coverage file. covbr honors covselect's persisted
  # exclusions on its own. No region arguments are needed.
  def report_branch_coverage_results()
    mode = @project_config[:bullseye_branch_detail]
    return if mode == BULLSEYE_BRANCH_DETAIL_NONE

    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVBR, boom: false, respect_optional: true )

    banner = @plugin_reportinator.generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: BRANCH COVERAGE DETAIL" )
    @loginator.log "\n" + banner

    command      = @tool_executor.build_command_line( TOOLS_BULLSEYE_REPORT_COVBR, [], BULLSEYE_BRANCH_DETAIL_FLAGS[mode] )
    shell_result = @tool_executor.exec( command )
    detail       = shell_result[:output].to_s.strip

    # covbr prints nothing in :uncovered mode when every probe is fully covered.
    if detail.empty?
      @loginator.log( "No uncovered branches.\n" )
    else
      @loginator.log( detail + "\n" )
    end
  end

  def thresholds_configured?
    thresholds = @project_config[:bullseye_fail_under] || {}
    return [thresholds[:functions].to_i, thresholds[:branches].to_i].any? { |minimum| minimum > 0 }
  end

  # Fails the build when measured coverage falls below a configured minimum.
  # A minimum of zero disables the check for that metric.
  #
  # Each shortfall is registered separately. The build failure summary then lists one
  # bullet per metric instead of one bullet carrying embedded newlines.
  def enforce_coverage_thresholds(totals)
    thresholds = @project_config[:bullseye_fail_under] || {}

    { :functions => 'Function', :branches => 'Branch' }.each do |metric, label|
      minimum = thresholds[metric].to_i
      next if minimum <= 0

      actual = totals.nil? ? nil : totals[metric]

      if actual.nil?
        message = "#{label} coverage is unavailable, but a minimum of #{minimum}% is configured."
      elsif actual < minimum
        message = "#{label} coverage #{actual}% is below the configured minimum of #{minimum}%."
      else
        next
      end

      @ceedling[:plugin_manager].register_build_failure( BULLSEYE_SYM, message )
    end
  end

  def report_per_function_coverage_results()
    banner = @plugin_reportinator.generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @loginator.log "\n" + banner

    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVFN, boom: false, respect_optional: true )

    coverage_sources = []
    @test_invoker.each_test_with_sources { |_, srcs| coverage_sources.concat( srcs ) }
    coverage_sources.uniq!
    # Every configured source extension is a valid ending for a mock/ignored-source name,
    # so the two are joined into one regex alternation rather than matching just one.
    source_extensions = EXTENSION_SOURCE.to_a.map { |ext| Regexp.escape(ext) }.join('|')
    coverage_sources.delete_if {|item| item =~ /#{@configurator.cmock_mock_prefix}.+(?:#{source_extensions})$/}
    coverage_sources.delete_if {|item| item =~ /(?:#{BULLSEYE_IGNORE_SOURCES.join('|')})(?:#{source_extensions})$/}

    coverage_sources.each do |source|
      command          = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_REPORT_COVFN, [], source)
      shell_results    = @ceedling[:tool_executor].exec( command )
      coverage_results = shell_results[:output].dup
      coverage_results.sub!(/.*\n.*\n/,'') # Remove the Bullseye tool banner
      if (coverage_results =~ /warning cov814: report is empty/)
        coverage_results = "#{source} contains no coverage data"
        @loginator.log(coverage_results, Verbosity::COMPLAIN)
      else
        coverage_results += "\n"
        @loginator.log(coverage_results)
      end
    end
  end

  def verify_coverage_file
    exist = @file_wrapper.exist?( ENVIRONMENT_COVFILE )

    if (!exist)
      banner = @plugin_reportinator.generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
      @loginator.log "\n" + banner + "\nNo coverage file.\n\n"
    end

    return exist
  end

end
