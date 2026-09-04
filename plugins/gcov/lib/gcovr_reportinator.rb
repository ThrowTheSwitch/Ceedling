# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/constants'
require 'gcov_types'
require 'gcov_reportinator'

class GcovrReportinator < GcovReportinator

  NAME = 'Gcovr'

  def name; NAME; end

  attr_reader :artifacts_path

  GCOVR_SETTING_PREFIX = :gcov_gcovr

  # Version floors for options whose behavior depends on the installed gcovr.
  # Checked upfront in initialize, once, rather than left to surface as gcovr's
  # own opaque CLI error or silently dropped -- either of which would leave a
  # configured feature quietly never actually active. :mcdc's value comes from
  # the top-level :gcov config (see initialize), not the :gcovr sub-namespace
  # the other two live under -- enforce_version_gates! doesn't care where its
  # opts hash came from, so both are checked together in one call.
  VERSION_GATES = {
    :mcdc => {
      min: [8, 0],
      message: ":gcov ↳ :mcdc ➡️ Modified condition/decision coverage reporting requires gcovr %{req} " \
                "or higher (found %{found})"
    },
    # A distinct, later addition than :decisions -- confirmed directly against real gcovr
    # 6.0, which rejects --fail-under-decision outright as an unrecognized argument.
    :fail_under_decision => {
      min: [7, 0],
      message: ":gcov ↳ :gcovr ↳ :fail_under_decision ➡️ requires gcovr %{req} or higher (found %{found})"
    },
    :decisions => {
      min: [5, 1],
      message: ":gcov ↳ :gcovr ↳ :decisions ➡️ requires gcovr %{req} or higher (found %{found})"
    },
  }.freeze

  # Declarative map of :gcov ↳ :gcovr options handled identically regardless of report
  # type (HTML/XML/JSON/text all share these) -- built once per generate_reports() call
  # and passed down rather than re-collected inside every args_builder_* method.
  # :branches/:sort_uncovered/:sort_percentage swap to their gcovr 7.0+ replacement flag
  # names (the pre-7.0 names still work but are deprecated) -- one row each documents both
  # the old and new mapping instead of a separate version-conditional code block.
  GCOVR_COMMON_ARGS = {
    :report_include        => { type: :value,   flag: '--filter' },
    :gcov_filter            => { type: :value,   flag: '--gcov-filter' },
    :gcov_exclude            => { type: :value,   flag: '--gcov-exclude' },
    :exclude_directories     => { type: :value,   flag: '--exclude-directories' },
    :branches                => { type: :boolean, flag: ->(v) { ToolVersionGating.min_version?(v, 7, 0) ? '--txt-metric branch' : '--branches' } },
    :sort_uncovered          => { type: :boolean, flag: ->(v) { ToolVersionGating.min_version?(v, 7, 0) ? '--sort uncovered-number' : '--sort-uncovered' } },
    :sort_percentage         => { type: :boolean, flag: ->(v) { ToolVersionGating.min_version?(v, 7, 0) ? '--sort uncovered-percent' : '--sort-percentage' } },
    :print_summary           => { type: :boolean, flag: '--print-summary' },
    :gcov_executable         => { type: :value,   flag: '--gcov-executable' },
    :exclude_unreachable_branches => { type: :boolean, flag: '--exclude-unreachable-branches' },
    :exclude_throw_branches  => { type: :boolean, flag: '--exclude-throw-branches' },
    :use_gcov_files          => { type: :boolean, flag: '--use-gcov-files' },
    :gcov_ignore_parse_errors => { type: :boolean, flag: '--gcov-ignore-parse-errors' },
    :keep                    => { type: :boolean, flag: '--keep' },
    :delete                  => { type: :boolean, flag: '--delete' },
    :threads                 => { type: :integer, flag: '-j' },
    # Merge mode is only available and relevant as of gcovr 6.0; silently omitted (not
    # raised) below that -- unlike VERSION_GATES above, an older gcovr simply never
    # merges function variants rather than the plugin blocking the whole build over it.
    :merge_mode_function     => { type: :value,   flag: '--merge-mode-functions', min_version: [6, 0] },
    # :decisions here is a derived value (see args_builder_common) -- gcovr treats
    # --fail-under-decision as a no-op without --decisions also present, so
    # :fail_under_decision being set implies this flag automatically.
    :decisions               => { type: :boolean, flag: '--decisions' },
    :fail_under_line         => { type: :integer_percent, flag: '--fail-under-line' },
    :fail_under_branch       => { type: :integer_percent, flag: '--fail-under-branch' },
    :fail_under_decision     => { type: :integer_percent, flag: '--fail-under-decision' },
    :fail_under_function     => { type: :integer_percent, flag: '--fail-under-function' },
    :source_encoding         => { type: :value, flag: '--source-encoding' },
    :object_directory        => { type: :value, flag: '--object-directory' },
  }.freeze

  def initialize(system_objects, config)
    super(config)

    @artifacts_path = GCOV_GCOVR_ARTIFACTS_PATH
    @summary        = ''
    @ceedling = system_objects

    # Validate the gcovr tool since it's used to generate reports
    @ceedling[:tool_validator].validate(
      tool: TOOLS_GCOV_GCOVR_REPORT,
      boom: true
    )

    # Convenient instance variable references
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
    @tool_executor = @ceedling[:tool_executor]
    @configurator = @ceedling[:configurator]

    check_config_options()

    @gcovr_version = get_gcovr_version()

    gcovr_opts = @config[GCOVR_SETTING_PREFIX] || {}

    enforce_version_gates!(
      {
        :mcdc                 => @configurator.gcov_mcdc,
        :fail_under_decision  => gcovr_opts[:fail_under_decision],
        :decisions            => gcovr_opts[:decisions],
      },
      @gcovr_version,
      VERSION_GATES
    )
  end

  # Generate the gcovr report(s) specified in the options.
  # Sets @summary when :print_summary is enabled; Gcov#generate_coverage_reports logs it.
  def generate_reports(opts)
    gcovr_opts        = collect_gcovr_opts(opts)
    exception_on_fail = !!gcovr_opts[:exception_on_fail]
    args_common       = args_builder_common(gcovr_opts, @gcovr_version)

    @loginator.log(@reportinator.generate_heading("Running Gcovr Coverage Reports"))

    # gcovr 4.2+ can produce all report formats in one invocation;
    # earlier versions require a separate call for each format.
    if min_version?(@gcovr_version, 4, 2)
      generate_reports_modern(gcovr_opts, args_common, exception_on_fail)
    else
      generate_reports_legacy(gcovr_opts, args_common, exception_on_fail)
    end

    # Text report is always a standalone gcovr invocation regardless of version.
    generate_text_report(gcovr_opts, args_common, exception_on_fail) if report_enabled?(gcovr_opts, ReportTypes::TEXT)
  end

  ### Private ###

  private

  # Build the gcovr report generation common arguments.
  # --root and --exclude are passed as positional args ${1} and ${2} to the tool executor
  # and are not included in the string returned by this method.
  def args_builder_common(gcovr_opts, gcovr_version)
    args = ""
    args += "--config \"#{gcovr_opts[:config_file]}\" " if config_file_in_use?(gcovr_opts)

    # #1159 -- applied even with a :config_file: in use (unlike every other option below):
    # this is the escape hatch for whatever gcovr flag Ceedling has no named option for (e.g.
    # limiting gcovr's search root), so it needs to keep working right alongside a config file,
    # not be deferred to it. Mirrors ReportGeneratorReportinator#build_optional_args' identical
    # :custom_args: handling for the ReportGenerator side (both call the shared base-class
    # build_custom_args).
    args += build_custom_args(gcovr_opts[:custom_args])

    # When a config file is provided, defer all other options to it.
    # This prevents Ceedling from overriding config file values with its CLI arguments.
    # --root (${1}) is always passed; --exclude (${2}) is nil when a config file is present,
    # so the tool executor omits those flags and the config file governs exclusions.
    return args if config_file_in_use?(gcovr_opts)

    # --fail-under-decision is a no-op to gcovr without --decisions also present (that's
    # what actually turns decision-coverage analysis on) -- :fail_under_decision implies
    # it automatically so the threshold option can never be configured into silently
    # failing outright. initialize already guarantees the gcovr version needed for
    # whichever of the two triggered this.
    gcovr_opts[:decisions] = true if gcovr_opts[:decisions] || !gcovr_opts[:fail_under_decision].nil?

    args += build_args_from_table(
      gcovr_opts, GCOVR_COMMON_ARGS,
      version: gcovr_version, component_prefix: ":gcov ↳ :gcovr"
    )

    return args
  end


  # Build the gcovr Cobertura XML report generation arguments.
  def args_builder_cobertura(gcovr_opts, use_output_option=false)
    args = ""

    # Determine if the Cobertura XML report is enabled. Defaults to disabled.
    if report_enabled?(gcovr_opts, ReportTypes::COBERTURA)
      # Determine the Cobertura XML report file name.
      artifacts_file_cobertura = GCOV_GCOVR_ARTIFACTS_FILE_COBERTURA
      if !(gcovr_opts[:cobertura_artifact_filename].nil?)
        artifacts_file_cobertura = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:cobertura_artifact_filename])
      end

      args += "--xml-pretty " if gcovr_opts[:cobertura_pretty] && !config_file_in_use?(gcovr_opts)
      args += "--xml #{use_output_option ? "--output " : ""} \"#{artifacts_file_cobertura}\" "
    end

    return args
  end


  # Build the gcovr SonarQube report generation arguments.
  def args_builder_sonarqube(gcovr_opts, use_output_option=false)
    args = ""

    # Determine if the gcovr SonarQube XML report is enabled. Defaults to disabled.
    if report_enabled?(gcovr_opts, ReportTypes::SONARQUBE)
      # Determine the SonarQube XML report file name.
      artifacts_file_sonarqube = GCOV_GCOVR_ARTIFACTS_FILE_SONARQUBE
      if !(gcovr_opts[:sonarqube_artifact_filename].nil?)
        artifacts_file_sonarqube = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:sonarqube_artifact_filename])
      end

      args += "--sonarqube #{use_output_option ? "--output " : ""} \"#{artifacts_file_sonarqube}\" "
    end

    return args
  end


  # Build the gcovr JSON report generation arguments.
  def args_builder_json(gcovr_opts, use_output_option=false)
    args = ""

    # Determine if the gcovr JSON report is enabled. Defaults to disabled.
    if report_enabled?( gcovr_opts, ReportTypes::JSON )
      # Determine the JSON report file name.
      artifacts_file_json = GCOV_GCOVR_ARTIFACTS_FILE_JSON
      if !(gcovr_opts[:json_artifact_filename].nil?)
        artifacts_file_json = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:json_artifact_filename])
      end

      args += "--json-pretty " if gcovr_opts[:json_pretty] && !config_file_in_use?(gcovr_opts)
      # Note: In gcovr 4.2, the JSON report is output only when the --output option is specified.
      # Hopefully we can remove --output after a future gcovr release.
      args += "--json #{use_output_option ? "--output " : ""} \"#{artifacts_file_json}\" "
    end

    return args
  end


  # Build the gcovr HTML report generation arguments.
  def args_builder_html(gcovr_opts, use_output_option=false)
    args = ""

    # Determine if the gcovr HTML report is enabled.
    html_enabled = report_enabled?(gcovr_opts, ReportTypes::HTML_BASIC) ||
                   report_enabled?(gcovr_opts, ReportTypes::HTML_DETAILED)

    if html_enabled
      # Determine the HTML report file name.
      artifacts_file_html = GCOV_GCOVR_ARTIFACTS_FILE_HTML
      if !(gcovr_opts[:html_artifact_filename].nil?)
        artifacts_file_html = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:html_artifact_filename])
      end

      is_html_report_type_detailed = (gcovr_opts[:gcov_html_report_type].is_a? String) && (gcovr_opts[:gcov_html_report_type].casecmp("detailed") == 0)

      args += "--html-details " if is_html_report_type_detailed || report_enabled?(gcovr_opts, ReportTypes::HTML_DETAILED)

      # These options duplicate settings a gcovr configuration file would provide, so they're
      # withheld when :config_file is set to avoid silently overriding the file's values.
      if !config_file_in_use?(gcovr_opts)
        args += "--html-title \"#{gcovr_opts[:html_title]}\" " unless gcovr_opts[:html_title].nil?
        args += "--html-absolute-paths " if gcovr_opts[:html_absolute_paths]
        args += "--html-encoding \"#{gcovr_opts[:html_encoding]}\" " unless gcovr_opts[:html_encoding].nil?

        [:html_medium_threshold, :html_high_threshold].each do |opt|
          args += "--#{opt.to_s.gsub('_','-')} #{gcovr_opts[opt]} " unless gcovr_opts[opt].nil?
        end
      end

      # The following option must be appended last for gcovr version <= 4.2 to properly work.
      args += "--html #{use_output_option ? "--output " : ""} \"#{artifacts_file_html}\" "
    end

    return args
  end


  # Generate a gcovr text report.
  # @summary is set by run_gcovr when :print_summary is enabled.
  def generate_text_report(gcovr_opts, args_common, boom)
    args_text = ""
    message_text = "Generating a text coverage report"

    filename = gcovr_opts[:text_artifact_filename] || GCOV_GCOVR_DEFAULT_TEXT_ARTIFACT_FILENAME

    artifacts_file_txt = File.join(GCOV_GCOVR_ARTIFACTS_PATH, filename)
    args_text += "--output \"#{artifacts_file_txt}\" "
    message_text += " in '#{GCOV_GCOVR_ARTIFACTS_PATH}'"

    msg = @reportinator.generate_progress(message_text)
    @loginator.log(msg, Verbosity::NORMAL)

    run_gcovr( gcovr_opts, (args_common + args_text), boom )
  end


  # gcovr 4.2+ supports all output formats in a single invocation.
  # Accumulate per-format args and track which formats are active for progress logging.
  # As required by gcovr 4.2, --html arguments must be appended last.
  # @summary is set by run_gcovr when :print_summary is enabled.
  def generate_reports_modern(gcovr_opts, args_common, exception_on_fail)
    reports = []
    args    = args_common

    args += (_args = args_builder_cobertura(gcovr_opts, false))
    reports << "Cobertura XML" unless _args.empty?

    args += (_args = args_builder_sonarqube(gcovr_opts, false))
    reports << "SonarQube" unless _args.empty?

    args += (_args = args_builder_json(gcovr_opts, true))
    reports << "JSON" unless _args.empty?

    # --html must be last (gcovr 4.2 requirement)
    args += (_args = args_builder_html(gcovr_opts, false))
    reports << "HTML" unless _args.empty?

    reports.each do |report|
      @loginator.log(
        @reportinator.generate_progress("Generating #{report} coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}/'"),
        Verbosity::NORMAL, LogLabels::NOTICE
      )
    end

    # Skip the gcovr call entirely when no format added arguments.
    return if args == args_common

    run_gcovr(gcovr_opts, args, exception_on_fail)
  end


  # gcovr 4.1 and earlier support only HTML and Cobertura XML, and each must be
  # generated with a separate gcovr call. SonarQube and JSON are unavailable.
  # @summary is set by run_gcovr when :print_summary is enabled.
  def generate_reports_legacy(gcovr_opts, args_common, exception_on_fail)
    args_html      = args_builder_html(gcovr_opts, true)
    args_cobertura = args_builder_cobertura(gcovr_opts, true)

    if args_html.length > 0
      @loginator.log(
        @reportinator.generate_progress("Generating an HTML coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
      )
      run_gcovr(gcovr_opts, args_common + args_html, exception_on_fail)
    end

    if args_cobertura.length > 0
      @loginator.log(
        @reportinator.generate_progress("Generating a Cobertura XML coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
      )
      run_gcovr(gcovr_opts, args_common + args_cobertura, exception_on_fail)
    end
  end


  # gcovr options silently ignored whenever :config_file is set (dropped by args_builder_common's
  # early return, or gated in args_builder_cobertura/json/html) -- in that case all such
  # configuration must come from the gcovr configuration file itself.
  IGNORED_WHEN_CONFIG_FILE_SET = [
    :report_include, :report_exclude, :gcov_filter, :gcov_exclude, :exclude_directories,
    :branches, :decisions, :sort_uncovered, :sort_percentage, :print_summary, :gcov_executable,
    :exclude_unreachable_branches, :exclude_throw_branches, :use_gcov_files, :gcov_ignore_parse_errors,
    :keep, :delete, :threads, :merge_mode_function,
    :fail_under_line, :fail_under_branch, :fail_under_decision, :fail_under_function,
    :source_encoding, :object_directory,
    :cobertura_pretty, :json_pretty,
    :html_title, :html_absolute_paths, :html_encoding, :html_medium_threshold, :html_high_threshold
  ].freeze

  # True when a gcovr configuration file is in use, meaning Ceedling must defer to it and
  # withhold any option that would silently override its settings.
  def config_file_in_use?(gcovr_opts)
    !gcovr_opts[:config_file].nil?
  end


  # Validate the gcovr plugin configuration for known-bad combinations.
  def check_config_options
    gcovr_opts = @config[GCOVR_SETTING_PREFIX] || {}
    return unless config_file_in_use?(gcovr_opts)

    ignored = IGNORED_WHEN_CONFIG_FILE_SET.select { |key| !gcovr_opts[key].nil? }
    return if ignored.empty?

    list = ignored.map { |key| ":#{key}" }.join(', ')
    msg = ":gcov ↳ :gcovr ↳ :config_file is set, so the following options are ignored: #{list}. " \
          "Provide equivalent settings directly in your gcovr configuration file instead."
    @loginator.log( msg, Verbosity::COMPLAIN )
  end


  # Get the gcovr options from the project options, plus the raw project options needed
  # for report-type/HTML-detail lookups that don't live under the :gcovr sub-namespace --
  # merged into one hash so every args_builder_* method needs only this single argument.
  def collect_gcovr_opts(opts)
    # dup prevents repeated calls from accumulating mutations on the shared opts hash.
    # This is computed once per generate_reports() call and threaded through, so this
    # guards against generate_reports() itself being called more than once, not (as
    # before) against each args_builder_* method re-deriving and re-mutating its own copy.
    _opts = opts[GCOVR_SETTING_PREFIX].dup

    if config_file_in_use?(_opts)
      # A gcovr config file is authoritative; CLI args override it, so injecting
      # auto-excludes would silently defeat the config file. Force an empty array
      # (not nil) so the tool executor omits the --exclude flag entirely.
      _opts[:report_exclude] = []
    else
      # Build array of --exclude patterns: user-provided value (if any) + internally-generated per-file patterns.
      # Splat via *Array() handles both a user-supplied string and a user-supplied array
      # without introducing a nested element into the exclusions list.
      excludes = build_report_exclusions()
      excludes.unshift( *Array(_opts[:report_exclude]) ) if _opts[:report_exclude]
      _opts[:report_exclude] = excludes unless excludes.empty?
    end

    # No :mcdc-specific gcovr flag to set here -- GCC's own condition/MC-DC data flows
    # into gcovr's reports unconditionally, in every format, regardless of --decisions
    # (confirmed directly: gcovr's Condition-labeled HTML/JSON content is byte-identical
    # with and without --decisions; that flag only adds its own separate, additive
    # Decision data alongside it). :mcdc's own gcovr-version floor is still enforced in
    # initialize -- there's just nothing more for gcovr's own CLI args to do here.
    _opts[:gcov_reports] = opts[:gcov_reports]
    _opts[:gcov_html_report_type] = opts[:gcov_html_report_type]

    return _opts
  end


  # Build a combined Python regex for gcovr's `--exclude` flag covering all
  # non-production file categories: test files, support files, and generated/framework files.
  # Path/prefix values are config-driven, so they're Regexp-escaped -- the same treatment
  # already given the source-extension alternation -- rather than interpolated raw, which
  # would let a metacharacter (e.g. a literal '.') in a project's own path silently
  # over- or under-match.
  def build_report_exclusions
    data = build_exclusion_data
    patterns = []

    # A source extension can be configured as more than one string, so its escaped forms
    # are joined into one alternation rather than assuming there's only ever one to match.
    src_extension_alternation = data[:src_extension].to_a.map { |ext| Regexp.escape(ext) }.join('|')
    test_prefix = Regexp.escape(data[:test_prefix].to_s)
    build_root = Regexp.escape(data[:build_root].to_s)

    data[:test_paths].each do |path|
      # Test files (e.g. test_foo.c)
      patterns << ".*#{Regexp.escape(path)}.*/#{test_prefix}.+(?:#{src_extension_alternation})$"
    end

    # Support files (e.g. helpers, stubs, fixtures) — never production source
    data[:support_paths].each do |path|
      patterns << ".*#{Regexp.escape(path)}/.+(?:#{src_extension_alternation})$"
    end

    # Any generated files for tests or vendored framework C source files below the root of the build directory
    patterns << ".*#{build_root}/.+\\#{EXTENSION_CORE_SOURCE}$"

    return patterns
  end


  # Runs gcovr with the given arguments.
  # Responsibilities:
  #  - Builds and executes the gcovr command
  #  - Prints raw shell output (success and failure)
  #  - Saves --print-summary output to @summary; Gcov#generate_coverage_reports logs it
  #  - Delegates exit-code interpretation to gcovr_exec_exception?
  #  - Returns shell_result on success or non-fatal exception; raises on fatal exception
  # gcovr_opts[:report_root] → ${1} (--root); gcovr_opts[:report_exclude] → ${2} (--exclude, array).
  def run_gcovr(gcovr_opts, args, boom)
    command = @tool_executor.build_command_line(
      TOOLS_GCOV_GCOVR_REPORT, [],
      gcovr_opts[:report_root],    # ${1} --root
      gcovr_opts[:report_exclude], # ${2} --exclude (array; expanded to one flag per entry)
      args                         # ${3} remaining optional arguments
    )

    shell_result = nil
    exception    = nil

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellException => ex
      exception    = ex
      shell_result = ex.shell_result
    end

    print_shell_exec_time( shell_result )
    @summary = extract_gcovr_summary( shell_result[:stdout] ) if gcovr_opts[:print_summary]

    raise( exception ) if exception && gcovr_exec_exception?( gcovr_opts, shell_result[:exit_code], boom, shell_result )
    return shell_result
  end


  # Returns the error message text from gcovr stderr, or nil if none found.
  # Matches lines beginning with "error" or "(ERROR)" and extracts the trailing message.
  def extract_gcovr_error_message(shell_result)
    return nil if shell_result.nil?

    stderr = shell_result[:stderr]
    return nil if stderr.nil? || stderr.empty?

    stderr.each_line do |line|
      match = line.match( /^\(?error\S*\s+(.+)/i )
      return match[1].strip.capitalize if match
    end

    nil
  end


  # Extract the last contiguous block of lines containing '%' from gcovr stdout.
  # gcovr --print-summary emits lines like "lines: 69.6% (80 out of 115)" — this
  # locates that block generically without depending on exact line labels.
  def extract_gcovr_summary(output)
    return '' if output.nil? || output.empty?

    lines = output.lines
    last_pct_idx = lines.rindex { |l| l.include?('%') }
    return '' if last_pct_idx.nil?

    first_pct_idx = last_pct_idx
    first_pct_idx -= 1 while first_pct_idx > 0 && lines[first_pct_idx - 1].include?('%')

    lines[first_pct_idx..last_pct_idx].join('')
  end


  # Get the gcovr version number as a ToolVersion struct.
  def get_gcovr_version()
    @loginator.lazy( Verbosity::OBNOXIOUS ) do
      @reportinator.generate_progress("Collecting gcovr version for conditional feature handling")
    end

    detect_tool_version( TOOLS_GCOV_GCOVR_VERSION, /gcovr (\d+)\.(\d+)/, tool_label: 'gcovr' )
  end


  # Output to console a human-friendly message on certain coverage failure exit codes.
  # Prefers the actual gcovr error text from stderr; falls back to descriptive strings.
  # gcovr's composite exit code bit-ORs every violated :fail_under_* threshold together --
  # every violated bit is collected and reported, not just whichever is checked first.
  def gcovr_exec_exception?(opts, exitcode, boom, shell_result=nil)
    violations = []

    {
      2  => [:fail_under_line,     'Line'],
      4  => [:fail_under_branch,   'Branch'],
      8  => [:fail_under_decision, 'Decision'],
      16 => [:fail_under_function, 'Function'],
    }.each do |bit, (option, label)|
      next unless ((exitcode & bit) == bit) && !opts[option].nil?

      fallback = "#{label} coverage is less than the configured minimum of #{opts[option]}%"
      violations << "Gcovr ⏩️ #{extract_gcovr_error_message( shell_result ) || fallback}"
      exitcode &= ~bit
    end

    if boom
      raise CeedlingException.new( violations.join("\n") ) unless violations.empty?
    else
      violations.each { |msg| @loginator.log( msg, Verbosity::COMPLAIN ) }
    end

    # A non-zero exit code is a problem
    return (exitcode != 0)
  end


  # Returns true if the given report type is enabled, otherwise returns false.
  def report_enabled?(gcovr_opts, report_type)
    return gcovr_opts[:gcov_reports].map(&:upcase).include?( report_type.upcase )
  end

end
