# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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

    # Validate :untested_sources configuration value — fail fast at setup, not at report time
    validate_untested_sources( @project_config )

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
  def pre_compile_register(arg_hash)
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

  # As pre_compile_register above, for the covlink-wrapped linker. Fires every run
  # regardless of whether this executable actually needs relinking, which is also what
  # lets post_build's summary print correctly even on a fully-cached bullseye:all
  # re-run -- @cli_bullseye_task marks that a bullseye: task ran at all, not that a
  # link did.
  def pre_link_register(arg_hash)
    return if (arg_hash[:context] != BULLSEYE_SYM)

    @cli_bullseye_task = true
    arg_hash[:tool] = TOOLS_BULLSEYE_LINKER
  end

  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    @mutex.synchronize do
      if ((result_file =~ /#{BULLSEYE_RESULTS_PATH}/) and (not @result_list.include?(result_file)))
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

      verbosity = (results[:counts][:failed] > 0) ? Verbosity::ERRORS : Verbosity::NORMAL
      @plugin_reportinator.run_test_results_report(hash, verbosity)
    end

    # coverage results
    return if (verify_coverage_file() == false)

    # covselect exclusions must be applied regardless of :summaries — covhtml honors
    # the same persisted selections, so this isn't just a console-output concern
    apply_report_exclusions()

    if summaries_enabled?
      report_per_function_coverage_results()
      report_coverage_results_all()
    end

    generate_html_report() if automatic_html_reporting_enabled?
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
    report_coverage_results_all() if summaries_enabled?
  end

  # Called within class and also externally by plugin Rakefile
  # No parameters enables the opportunity for latter mechanism
  def automatic_html_reporting_enabled?
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
      @ceedling[:plugin_manager].register_build_failure( BULLSEYE_SYM, ex.message )
    end
  end

  private ###################################

  def validate_untested_sources(config)
    value = config[:bullseye_untested_sources]
    if not BULLSEYE_UNTESTED_SOURCES_OPTIONS.include?( value )
      options = BULLSEYE_UNTESTED_SOURCES_OPTIONS.map{ |opt| "':#{opt}'" }.join(', ')
      msg = "Plugin configuration :bullseye ↳ :untested_sources ➡️ `#{value.inspect}` is not a recognized option {#{options}}."
      raise CeedlingException.new(msg)
    end
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

  # No region arguments are passed to covsrc here — it reports against the whole
  # coverage file, honoring whatever exclusions apply_report_exclusions already
  # registered via covselect.
  def report_coverage_results_all()
    @ceedling[:tool_validator].validate( tool: TOOLS_BULLSEYE_REPORT_COVSRC, boom: false, respect_optional: true )

    command      = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_REPORT_COVSRC, [])
    shell_result = @ceedling[:tool_executor].exec( command )
    coverage     = shell_result[:output]

    results = {
      :context => BULLSEYE_SYM,
      :coverage => {
        :functions => nil,
        :branches  => nil
      }
    }

    if (coverage =~ /^Total.*?=\s+([0-9]+)\%/)
      results[:coverage][:functions] = $1.to_i
    end

    if (coverage =~ /^Total.*=\s+([0-9]+)\%\s*$/)
      results[:coverage][:branches] = $1.to_i
    end

    @plugin_reportinator.run_report( @coverage_template_all, results )
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
