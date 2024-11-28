# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'reportinator_helper'
require 'ceedling/exceptions'
require 'ceedling/constants'

class GcovrReportinator

  attr_reader :artifacts_path

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
  end

  # Generate the gcovr report(s) specified in the options.
  def generate_reports(opts)
    # Get the gcovr version number.
    gcovr_version = get_gcovr_version()

    # Get gcovr options from project configuration options
    gcovr_opts = get_gcovr_opts(opts)

    # Extract exception_on_fail setting
    exception_on_fail = !!gcovr_opts[:exception_on_fail]

    # Build the common gcovr arguments.
    args_common = args_builder_common( gcovr_opts, gcovr_version )

    msg = @reportinator.generate_heading( "Running Gcovr Coverage Reports" )
    @loginator.log( msg )

    # gcovr version 4.2 and later supports generating multiple reports with a single call.
    if min_version?( gcovr_version, 4, 2 )
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
        msg = @reportinator.generate_progress("Generating #{report} coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
        @loginator.log( msg )
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
        run( gcovr_opts, args, exception_on_fail )
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
        run( gcovr_opts, (args_common + args_html), exception_on_fail )
      end

      if args_cobertura.length > 0
        msg = @reportinator.generate_progress("Generating an Cobertura XML coverage report in '#{GCOV_GCOVR_ARTIFACTS_PATH}'")
        @loginator.log( msg )

        # Generate the Cobertura XML report.
        run( gcovr_opts, (args_common + args_cobertura), exception_on_fail )
      end
    end

    # Determine if the gcovr text report is enabled. Defaults to disabled.
    if report_enabled?(opts, ReportTypes::TEXT)
      generate_text_report( opts, args_common, exception_on_fail )
    end

    # White space log line
    @loginator.log( '' )
  end

  ### Private ###

  private

  GCOVR_SETTING_PREFIX = "gcov_gcovr"

  # Build the gcovr report generation common arguments.
  def args_builder_common(gcovr_opts, gcovr_version)
    args = ""
    args += "--root \"#{gcovr_opts[:report_root]}\" " unless gcovr_opts[:report_root].nil?
    args += "--config \"#{gcovr_opts[:config_file]}\" " unless gcovr_opts[:config_file].nil?
    args += "--filter \"#{gcovr_opts[:report_include]}\" " unless gcovr_opts[:report_include].nil?
    args += "--exclude \"#{gcovr_opts[:report_exclude]}\" " unless gcovr_opts[:report_exclude].nil?
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
          raise CeedlingException.new(":gcov ↳ :gcovr ↳ :#{opt} => '#{value}' must be an integer")
        elsif (value < 0) || (value > 100)
          raise CeedlingException.new(":gcov ↳ :gcovr ↳ :#{opt} => '#{value}' must be an integer percentage 0 – 100")
        end
      end
      
      # If the YAML key has a value, trasnform key into command line argument with value and concatenate
      args += "--#{opt.to_s.gsub('_','-')} #{value} " unless value.nil?
    end

    return args
  end


  # Build the gcovr Cobertura XML report generation arguments.
  def args_builder_cobertura(opts, use_output_option=false)
    gcovr_opts = get_gcovr_opts(opts)
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
    gcovr_opts = get_gcovr_opts(opts)
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
    gcovr_opts = get_gcovr_opts( opts )
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
    gcovr_opts = get_gcovr_opts(opts)
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
    gcovr_opts = get_gcovr_opts(opts)
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
  def get_gcovr_opts(opts)
    return opts[GCOVR_SETTING_PREFIX.to_sym]
  end


  # Run gcovr with the given arguments
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
  end


  # Get the gcovr version number as components
  # Return {:major, :minor}
  def get_gcovr_version()
    major = 0
    minor = 0

    command = @tool_executor.build_command_line(TOOLS_GCOV_GCOVR_REPORT, [], "--version")

    msg = @reportinator.generate_progress("Collecting gcovr version for conditional feature handling")
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    shell_result = @tool_executor.exec( command )
    version_number_match_data = shell_result[:output].match(/gcovr ([0-9]+)\.([0-9]+)/)

    if !(version_number_match_data.nil?) && !(version_number_match_data[1].nil?) && !(version_number_match_data[2].nil?)
        major = version_number_match_data[1].to_i
        minor = version_number_match_data[2].to_i
    else
      raise CeedlingException.new( "Could not collect `gcovr` version from its command line" )
    end

    return {:major => major, :minor => minor}
  end


  # Process version hash from `get_gcovr_version()`
  def min_version?(version, major, minor)
    # Meet minimum requirement if major version is greater than minimum major threshold
    return true if version[:major] > major

    # Meet minimum requirement only if greater than or equal to minor version for the same major version
    return true if version[:major] == major and version[:minor] >= minor

    # Version is less than major.minor
    return false
  end


  # Output to console a human-friendly message on certain coverage failure exit codes
  # Perform the logic on whether to raise an exception
  def gcovr_exec_exception?(opts, exitcode, boom)

    # Special handling of exit code 2 with --fail-under-line
    if ((exitcode & 2) == 2) and !opts[:gcovr][:fail_under_line].nil?
      msg = "Line coverage is less than the configured gcovr minimum of #{opts[:gcovr][:fail_under_line]}%"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~2
      end
    end

    # Special handling of exit code 4 with --fail-under-branch
    if ((exitcode & 4) == 4) and !opts[:gcovr][:fail_under_branch].nil?
      msg = "Branch coverage is less than the configured gcovr minimum of #{opts[:gcovr][:fail_under_branch]}%"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~4
      end
    end

    # Special handling of exit code 8 with --fail-under-decision
    if ((exitcode & 8) == 8) and !opts[:gcovr][:fail_under_decision].nil?
      msg = "Decision coverage is less than the configured gcovr minimum of #{opts[:gcovr][:fail_under_decision]}%"
      if boom
        raise CeedlingException.new(msg)
      else
        @loginator.log( msg, Verbosity::COMPLAIN )
        # Clear bit in exit code
        exitcode &= ~8
      end
    end

    # Special handling of exit code 16 with --fail-under-function
    if ((exitcode & 16) == 16) and !opts[:gcovr][:fail_under_function].nil?
      msg = "Function coverage is less than the configured gcovr minimum of #{opts[:gcovr][:fail_under_function]}%"
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
