# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'reportinator_helper'
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
    @ceedling = system_objects
    @reportinator_helper = ReportinatorHelper.new(system_objects)

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
  # Returns a summary string (possibly empty) when :print_summary is enabled.
  def generate_reports(opts)
    # Get gcovr options from project configuration options
    gcovr_opts = collect_gcovr_opts(opts)

    # Extract exception_on_fail setting
    exception_on_fail = !!gcovr_opts[:exception_on_fail]

    # Build the common gcovr arguments.
    args_common = args_builder_common( gcovr_opts, @gcovr_version )

    gcovr_summary = ''

    msg = @reportinator.generate_heading( "Running Gcovr Coverage Reports" )
    @loginator.log( msg )

    # gcovr version 4.2 and later supports generating multiple reports with a single call.
    if min_version?( @gcovr_version, 4, 2 )
      reports = []

      args = args_common

      args += (_args = args_builder_cobertura(opts, false))
      reports << "Cobertura XML" if not _args.empty?

      args += (_args = args_builder_sonarqube(opts, false))
      reports << "SonarQube" if not _args.empty?

      args += (_args = args_builder_json(opts, true))
      reports << "JSON" if not _args.empty?

      # As of gcovr version 4.2, the --html argument must appear last.
      args += (_args = args_builder_html(opts, false))
      reports << "HTML" if not _args.empty?

      reports.each do |report|
        msg = @reportinator.generate_progress("Generating #{report} coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}/'")
        @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
      end

      # Generate the report(s).
      # only if one of the previous done checks for:
      #
      # - args_builder_cobertura
      # - args_builder_sonarqube
      # - args_builder_json
      # - args_builder_html
      #
      # updated the args variable. In other case, no need to run GCOVR for current setup.
      if !(args == args_common)
        shell_result = run( gcovr_opts, args, exception_on_fail )
        if gcovr_opts[:print_summary] && shell_result
          gcovr_summary = extract_gcovr_summary( shell_result[:output] )
        end
      end

    # gcovr version 4.1 and earlier supports HTML and Cobertura XML reports.
    # It does not support SonarQube and JSON reports.
    # Reports must also be generated separately.
    else
      args_cobertura = args_builder_cobertura(opts, true)
      args_html = args_builder_html(opts, true)

      if args_html.length > 0
        msg = @reportinator.generate_progress("Generating an HTML coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
        @loginator.log( msg )

        # Generate the HTML report.
        shell_result = run( gcovr_opts, (args_common + args_html), exception_on_fail )
        if gcovr_opts[:print_summary] && shell_result && gcovr_summary.empty?
          gcovr_summary = extract_gcovr_summary( shell_result[:output] )
        end
      end

      if args_cobertura.length > 0
        msg = @reportinator.generate_progress("Generating an Cobertura XML coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
        @loginator.log( msg )

        # Generate the Cobertura XML report.
        shell_result = run( gcovr_opts, (args_common + args_cobertura), exception_on_fail )
        if gcovr_opts[:print_summary] && shell_result && gcovr_summary.empty?
          gcovr_summary = extract_gcovr_summary( shell_result[:output] )
        end
      end
    end

    # Determine if the gcovr text report is enabled. Defaults to disabled.
    if report_enabled?(opts, ReportTypes::TEXT)
      generate_text_report( opts, args_common, exception_on_fail )
    end

    # White space log line
    @loginator.log( '' )

    return gcovr_summary
  end

  ### Private ###

  private

  # Build the gcovr report generation common arguments.
  def args_builder_common(gcovr_opts, gcovr_version)
    args = ""
    args += "--root \"#{gcovr_opts[:report_root]}\" " unless gcovr_opts[:report_root].nil?
    args += "--config \"#{gcovr_opts[:config_file]}\" " unless gcovr_opts[:config_file].nil?

    # When a config file is provided, defer all other options to it.
    # This prevents Ceedling from overriding config file values with its CLI arguments.
    # Only :report_root is still applied because Ceedling may invoke gcovr from a
    # different working directory than the project root.
    return args if gcovr_opts[:config_file]

    args += "--filter \"#{gcovr_opts[:report_include]}\" " unless gcovr_opts[:report_include].nil?
    Array(gcovr_opts[:report_exclude]).each { |pat| args += "--exclude \"#{pat}\" " }
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


  # Generate a gcovr text report
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

    # Generate the text report
    run( gcovr_opts, (args_common + args_text), boom )
  end


  # Get the gcovr options from the project options.
  def collect_gcovr_opts(opts)
    _opts = opts[GCOVR_SETTING_PREFIX.to_sym]

    # Only auto-generate --exclude patterns when no config file is specified.
    # A gcovr config file is authoritative; CLI args override it, so injecting
    # auto-excludes would silently defeat the config file.
    unless _opts[:config_file]
      # Build array of --exclude patterns: user-provided string (if any) + auto-generated per-file patterns
      excludes = build_report_exclusions()
      excludes.unshift( _opts[:report_exclude] ) if _opts[:report_exclude]
      _opts[:report_exclude] = excludes unless excludes.empty?
    end

    _opts[:mcdc] = true if opts[:gcov_mcdc]

    return _opts
  end


  # Build a combined Python regex for gcovr's `--exclude`` flag covering all
  # non-production file categories: test files, mocks, partials, and framework.
  def build_report_exclusions()
    patterns = []

    test_prefix = @configurator.project_test_file_prefix
    @configurator.collection_paths_test.each do |path|
      # Test files (e.g. test_foo.c)
      patterns << ".*#{path}.*/#{test_prefix}.+\\#{@configurator.extension_source}$"      
    end

    # Any generated files for tests or vendored framework C source files below the root of the build directory
    build_root = @configurator.project_build_root
    patterns << ".*#{build_root}/.+\\#{EXTENSION_CORE_SOURCE}$"

    return patterns
  end


  # Run gcovr with the given arguments; returns shell_result (or nil on handled exception)
  def run(opts, args, boom)
    command = @tool_executor.build_command_line(TOOLS_GCOV_GCOVR_REPORT, [], args)

    shell_result = nil

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellException => ex
      result = ex.shell_result
      @reportinator_helper.print_shell_result( result )
      raise(ex) if gcovr_exec_exception?( opts, result[:exit_code], boom )
    end

    @reportinator_helper.print_shell_result( shell_result )
    return shell_result
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


  # Output to console a human-friendly message on certain coverage failure exit codes
  # Perform the logic on whether to raise an exception
  def gcovr_exec_exception?(opts, exitcode, boom)
    
    # Special handling of exit code 2 with --fail-under-line
    if ((exitcode & 2) == 2) and !opts[:fail_under_line].nil?
      msg = "Line coverage is less than the configured gcovr minimum of #{opts[:fail_under_line]}%"
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
      msg = "Branch coverage is less than the configured gcovr minimum of #{opts[:fail_under_branch]}%"
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
      msg = "Decision coverage is less than the configured gcovr minimum of #{opts[:fail_under_decision]}%"
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
      msg = "Function coverage is less than the configured gcovr minimum of #{opts[:fail_under_function]}%"
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
