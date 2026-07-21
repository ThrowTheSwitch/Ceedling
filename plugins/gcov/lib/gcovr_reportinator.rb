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

  GCOVR_SETTING_PREFIX = "gcov_gcovr"

  def initialize(system_objects)
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

    @gcovr_version = get_gcovr_version()

    # MC/DC reporting requires gcovr 8+
    if @configurator.gcov_mcdc && !min_version?( @gcovr_version, 8, 0 )
      raise CeedlingException.new(
        ":gcov ↳ :mcdc ➡️ Modified condition/decision coverage reporting requires gcovr 8 or higher " \
        "(found #{@gcovr_version.major}.#{@gcovr_version.minor})"
      )
    end
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
      generate_reports_modern(gcovr_opts, args_common, exception_on_fail, opts)
    else
      generate_reports_legacy(gcovr_opts, args_common, exception_on_fail, opts)
    end

    # Text report is always a standalone gcovr invocation regardless of version.
    generate_text_report(opts, args_common, exception_on_fail) if report_enabled?(opts, ReportTypes::TEXT)
  end

  ### Private ###

  private

  # Build the gcovr report generation common arguments.
  # --root and --exclude are passed as positional args ${1} and ${2} to the tool executor
  # and are not included in the string returned by this method.
  def args_builder_common(gcovr_opts, gcovr_version)
    args = ""
    args += "--config \"#{gcovr_opts[:config_file]}\" " unless gcovr_opts[:config_file].nil?

    # When a config file is provided, defer all other options to it.
    # This prevents Ceedling from overriding config file values with its CLI arguments.
    # --root (${1}) is always passed; --exclude (${2}) is nil when a config file is present,
    # so the tool executor omits those flags and the config file governs exclusions.
    return args if gcovr_opts[:config_file]

    args += "--filter \"#{gcovr_opts[:report_include]}\" " unless gcovr_opts[:report_include].nil?
    args += "--gcov-filter \"#{gcovr_opts[:gcov_filter]}\" " unless gcovr_opts[:gcov_filter].nil?
    args += "--gcov-exclude \"#{gcovr_opts[:gcov_exclude]}\" " unless gcovr_opts[:gcov_exclude].nil?
    args += "--exclude-directories \"#{gcovr_opts[:exclude_directories]}\" " unless gcovr_opts[:exclude_directories].nil?
    args += "--branches " if gcovr_opts[:branches]
    args += "--sort-uncovered " if gcovr_opts[:sort_uncovered]
    args += "--sort-percentage " if gcovr_opts[:sort_percentage]
    args += "--print-summary " if gcovr_opts[:print_summary]
    args += "--gcov-executable \"#{gcovr_opts[:gcov_executable]}\" " unless gcovr_opts[:gcov_executable].nil?
    args += "--exclude-unreachable-branches " if gcovr_opts[:exclude_unreachable_branches]
    args += "--exclude-throw-branches " if gcovr_opts[:exclude_throw_branches]
    args += "--use-gcov-files " if gcovr_opts[:use_gcov_files]
    args += "--gcov-ignore-parse-errors " if gcovr_opts[:gcov_ignore_parse_errors]
    args += "--keep " if gcovr_opts[:keep]
    args += "--delete " if gcovr_opts[:delete]
    args += "-j #{gcovr_opts[:threads]} " if !(gcovr_opts[:threads].nil?) && (gcovr_opts[:threads].is_a? Integer)

    # Version check -- merge mode is only available and relevant as of gcovr 6.0
    if min_version?( gcovr_version, 6, 0 )
      args += "--merge-mode-functions \"#{gcovr_opts[:merge_mode_function]}\" " unless gcovr_opts[:merge_mode_function].nil?
    end

    [:fail_under_line,
     :fail_under_branch,
     :fail_under_decision,
     :fail_under_function,
     :source_encoding,
     :object_directory
    ].each do |opt|
      next if gcovr_opts[opt].nil?

      value = gcovr_opts[opt]
      
      # Value sanity checks for :fail_under_* settings
      if opt.to_s =~ /fail_/
        if not value.is_a? Integer
          raise CeedlingException.new(":gcov ↳ :gcovr ↳ :#{opt} ➡️ '#{value}' must be an integer")
        elsif (value < 0) || (value > 100)
          raise CeedlingException.new(":gcov ↳ :gcovr ↳ :#{opt} ➡️ '#{value}' must be an integer percentage 0 – 100")
        end
      end
      
      # If the YAML key has a value, trasnform key into command line argument with value and concatenate
      args += "--#{opt.to_s.gsub('_','-')} #{value} " unless value.nil?
    end

    return args
  end


  # Build the gcovr Cobertura XML report generation arguments.
  def args_builder_cobertura(opts, use_output_option=false)
    gcovr_opts = collect_gcovr_opts(opts)
    args = ""

    # Determine if the Cobertura XML report is enabled. Defaults to disabled.
    if report_enabled?(opts, ReportTypes::COBERTURA)
      # Determine the Cobertura XML report file name.
      artifacts_file_cobertura = GCOV_GCOVR_ARTIFACTS_FILE_COBERTURA
      if !(gcovr_opts[:cobertura_artifact_filename].nil?)
        artifacts_file_cobertura = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:cobertura_artifact_filename])
      end

      args += "--xml-pretty " if gcovr_opts[:cobertura_pretty]
      args += "--xml #{use_output_option ? "--output " : ""} \"#{artifacts_file_cobertura}\" "
    end

    return args
  end


  # Build the gcovr SonarQube report generation arguments.
  def args_builder_sonarqube(opts, use_output_option=false)
    gcovr_opts = collect_gcovr_opts(opts)
    args = ""

    # Determine if the gcovr SonarQube XML report is enabled. Defaults to disabled.
    if report_enabled?(opts, ReportTypes::SONARQUBE)
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
  def args_builder_json(opts, use_output_option=false)
    gcovr_opts = collect_gcovr_opts( opts )
    args = ""

    # Determine if the gcovr JSON report is enabled. Defaults to disabled.
    if report_enabled?( opts, ReportTypes::JSON )
      # Determine the JSON report file name.
      artifacts_file_json = GCOV_GCOVR_ARTIFACTS_FILE_JSON
      if !(gcovr_opts[:json_artifact_filename].nil?)
        artifacts_file_json = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:json_artifact_filename])
      end

      args += "--json-pretty " if gcovr_opts[:json_pretty]
      # Note: In gcovr 4.2, the JSON report is output only when the --output option is specified.
      # Hopefully we can remove --output after a future gcovr release.
      args += "--json #{use_output_option ? "--output " : ""} \"#{artifacts_file_json}\" "
    end

    return args
  end


  # Build the gcovr HTML report generation arguments.
  def args_builder_html(opts, use_output_option=false)
    gcovr_opts = collect_gcovr_opts(opts)
    args = ""

    # Determine if the gcovr HTML report is enabled.
    html_enabled = report_enabled?(opts, ReportTypes::HTML_BASIC) ||
                   report_enabled?(opts, ReportTypes::HTML_DETAILED)

    if html_enabled
      # Determine the HTML report file name.
      artifacts_file_html = GCOV_GCOVR_ARTIFACTS_FILE_HTML
      if !(gcovr_opts[:html_artifact_filename].nil?)
        artifacts_file_html = File.join(GCOV_GCOVR_ARTIFACTS_PATH, gcovr_opts[:html_artifact_filename])
      end

      is_html_report_type_detailed = (opts[:gcov_html_report_type].is_a? String) && (opts[:gcov_html_report_type].casecmp("detailed") == 0)

      args += "--html-details " if is_html_report_type_detailed || report_enabled?(opts, ReportTypes::HTML_DETAILED)
      args += "--html-title \"#{gcovr_opts[:html_title]}\" " unless gcovr_opts[:html_title].nil?
      args += "--html-absolute-paths " if !(gcovr_opts[:html_absolute_paths].nil?) && gcovr_opts[:html_absolute_paths]
      args += "--html-encoding \"#{gcovr_opts[:html_encoding]}\" " unless gcovr_opts[:html_encoding].nil?

      [:html_medium_threshold, :html_high_threshold].each do |opt|
        args += "--#{opt.to_s.gsub('_','-')} #{gcovr_opts[opt]} " unless gcovr_opts[opt].nil?
      end

      # The following option must be appended last for gcovr version <= 4.2 to properly work.
      args += "--html #{use_output_option ? "--output " : ""} \"#{artifacts_file_html}\" "
    end

    return args
  end


  # Generate a gcovr text report.
  # @summary is set by run_gcovr when :print_summary is enabled.
  def generate_text_report(opts, args_common, boom)
    gcovr_opts = collect_gcovr_opts(opts)
    args_text = ""
    message_text = "Generating a text coverage report"

    filename = gcovr_opts[:text_artifact_filename] || 'coverage.txt'

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
  def generate_reports_modern(gcovr_opts, args_common, exception_on_fail, opts)
    reports = []
    args    = args_common

    args += (_args = args_builder_cobertura(opts, false))
    reports << "Cobertura XML" unless _args.empty?

    args += (_args = args_builder_sonarqube(opts, false))
    reports << "SonarQube" unless _args.empty?

    args += (_args = args_builder_json(opts, true))
    reports << "JSON" unless _args.empty?

    # --html must be last (gcovr 4.2 requirement)
    args += (_args = args_builder_html(opts, false))
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
  def generate_reports_legacy(gcovr_opts, args_common, exception_on_fail, opts)
    args_html      = args_builder_html(opts, true)
    args_cobertura = args_builder_cobertura(opts, true)

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


  # Get the gcovr options from the project options.
  def collect_gcovr_opts(opts)
    # dup prevents repeated calls from accumulating mutations on the shared opts hash.
    # Each args_builder_* method calls this independently, so without dup every call
    # would see the already-mutated :report_exclude from the previous call and nest it.
    _opts = opts[GCOVR_SETTING_PREFIX.to_sym].dup

    if _opts[:config_file]
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

    _opts[:mcdc] = true if opts[:gcov_mcdc]

    return _opts
  end


  # Build a combined Python regex for gcovr's `--exclude` flag covering all
  # non-production file categories: test files, support files, and generated/framework files.
  def build_report_exclusions
    data = build_exclusion_data
    patterns = []

    data[:test_paths].each do |path|
      # Test files (e.g. test_foo.c)
      patterns << ".*#{path}.*/#{data[:test_prefix]}.+\\#{data[:src_extension]}$"
    end

    # Support files (e.g. helpers, stubs, fixtures) — never production source
    data[:support_paths].each do |path|
      patterns << ".*#{path}/.+\\#{data[:src_extension]}$"
    end

    # Any generated files for tests or vendored framework C source files below the root of the build directory
    patterns << ".*#{data[:build_root]}/.+\\#{EXTENSION_CORE_SOURCE}$"

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


  # Get the gcovr version number as GcovToolVersion struct
  def get_gcovr_version()
    command = @tool_executor.build_command_line( TOOLS_GCOV_GCOVR_VERSION, [] )

    @loginator.lazy( Verbosity::OBNOXIOUS ) do
      @reportinator.generate_progress("Collecting gcovr version for conditional feature handling")
    end

    shell_result = @tool_executor.exec( command )
    version_match = shell_result[:output].match(/gcovr (\d+)\.(\d+)/)

    if version_match.nil? || version_match[1].nil? || version_match[2].nil?
      raise CeedlingException.new( "Could not collect `gcovr` version from its command line" )
    end

    return GcovToolVersion.new( version_match[1].to_i, version_match[2].to_i )
  end


  # Process GcovToolVersion struct from `get_gcovr_version()`
  def min_version?(version, major, minor)
    return true if version.major > major
    return true if version.major == major && version.minor >= minor
    return false
  end


  # Output to console a human-friendly message on certain coverage failure exit codes.
  # Prefers the actual gcovr error text from stderr; falls back to descriptive strings.
  # Perform the logic on whether to raise an exception
  def gcovr_exec_exception?(opts, exitcode, boom, shell_result=nil)

    # Special handling of exit code 2 with --fail-under-line
    if ((exitcode & 2) == 2) and !opts[:fail_under_line].nil?
      fallback = "Line coverage is less than the configured minimum of #{opts[:fail_under_line]}%"
      msg = "Gcovr ⏩️ #{extract_gcovr_error_message( shell_result ) || fallback}"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~2
      end
    end

    # Special handling of exit code 4 with --fail-under-branch
    if ((exitcode & 4) == 4) and !opts[:fail_under_branch].nil?
      fallback = "Branch coverage is less than the configured minimum of #{opts[:fail_under_branch]}%"
      msg = "Gcovr ⏩️ #{extract_gcovr_error_message( shell_result ) || fallback}"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~4
      end
    end

    # Special handling of exit code 8 with --fail-under-decision
    if ((exitcode & 8) == 8) and !opts[:fail_under_decision].nil?
      fallback = "Decision coverage is less than the configured minimum of #{opts[:fail_under_decision]}%"
      msg = "Gcovr ⏩️ #{extract_gcovr_error_message( shell_result ) || fallback}"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~8
      end
    end

    # Special handling of exit code 16 with --fail-under-function
    if ((exitcode & 16) == 16) and !opts[:fail_under_function].nil?
      fallback = "Function coverage is less than the configured minimum of #{opts[:fail_under_function]}%"
      msg = "Gcovr ⏩️ #{extract_gcovr_error_message( shell_result ) || fallback}"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~16
      end
    end

    # A non-zero exit code is a problem
    return (exitcode != 0)
  end


  # Returns true if the given report type is enabled, otherwise returns false.
  def report_enabled?(opts, report_type)
    return opts[:gcov_reports].map(&:upcase).include?( report_type.upcase )
  end

end
