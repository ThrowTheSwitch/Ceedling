# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'benchmark'
require 'reportinator_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'

class ReportGeneratorReportinator

  attr_reader :artifacts_path

  def initialize(system_objects)
    @artifacts_path = GCOV_REPORT_GENERATOR_ARTIFACTS_PATH
    @ceedling = system_objects
    @reportinator_helper = ReportinatorHelper.new(system_objects)

    # Validate the `reportgenerator` tool since it's used to generate reports
    @ceedling[:tool_validator].validate( 
      tool: TOOLS_GCOV_REPORTGENERATOR_REPORT,
      boom: true
    )

    # Validate the `gcov` report tool since it's used to generate .gcov files processed by `reportgenerator`
    # Note: This gcov tool is a different configuration than the gcov tool used for coverage summaries
    @ceedling[:tool_validator].validate(
      tool: TOOLS_GCOV_REPORT,
      boom: true
    )

    # Convenient instance variable references
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
    @tool_executor = @ceedling[:tool_executor]
  end


  # Generate the ReportGenerator report(s) specified in the options.
  def generate_reports(opts)
    shell_result = nil
    total_time = Benchmark.realtime do
      rg_opts = get_opts(opts)

      msg = @reportinator.generate_heading( "Running ReportGenerator Coverage Reports" )
      @loginator.log( msg )

      opts[:gcov_reports].each do |report|
        msg = @reportinator.generate_progress("Generating #{report} coverage report in '#{GCOV_REPORT_GENERATOR_ARTIFACTS_PATH}'")
        @loginator.log( msg )
      end

      # Cleanup any existing .gcov files to avoid reporting old coverage results.
      for gcov_file in Dir.glob("*.gcov")
        File.delete(gcov_file)
      end

      gcno_exclude_str = ""

      # Avoid running gcov on custom specified .gcno files.
      for gcno_exclude_expression in rg_opts[:gcov_exclude]
        if !(gcno_exclude_expression.nil?) && !(gcno_exclude_expression.empty?)
          # We want to filter .gcno files, not .gcov files.
          # We will generate .gcov files from .gcno files.
          gcno_exclude_expression = gcno_exclude_expression.chomp("\\.gcov")
          gcno_exclude_expression = gcno_exclude_expression.chomp(".gcov")
          # The .gcno extension will be added later as we create the regex.
          gcno_exclude_expression = gcno_exclude_expression.chomp("\\.gcno")
          gcno_exclude_expression = gcno_exclude_expression.chomp(".gcno")
          # Append the custom expression.
          gcno_exclude_str += "|#{gcno_exclude_expression}"
        end
      end

      gcno_exclude_regex = /(\/|\\)(#{gcno_exclude_str})\.gcno/

      # Generate .gcov files by running gcov on gcov notes files (*.gcno).
      for gcno_filepath in Dir.glob(File.join(GCOV_BUILD_PATH, "**", "*.gcno"))
        if not (gcno_filepath =~ gcno_exclude_regex) # Skip path that matches exclude pattern
          # Ensure there is a matching gcov data file.
          if File.file?(gcno_filepath.gsub(".gcno", ".gcda"))
            run_gcov("\"#{gcno_filepath}\"")
          end
        end
      end

      if Dir.glob("*.gcov").length > 0
        # Build the command line arguments.
        args = args_builder(opts)

        # Generate the report(s).
        begin
          shell_result = run(args)
        rescue ShellException => ex
          shell_result = ex.shell_result
          # Re-raise
          raise ex
        ensure
          # Cleanup .gcov files.
          for gcov_file in Dir.glob("*.gcov")
            File.delete(gcov_file)
          end          
        end
      else
        @loginator.log( "No matching .gcno coverage files found", Verbosity::COMPLAIN )
      end

    end

    if shell_result
      shell_result[:time] = total_time
      @reportinator_helper.print_shell_result(shell_result)
    end

    # White space log line
    @loginator.log( '' )
  end


  private

  # A dictionary of report types defined in this plugin to ReportGenerator report types.
  REPORT_TYPE_TO_REPORT_GENERATOR_REPORT_NAME = {
    ReportTypes::HTML_BASIC.upcase => "HtmlSummary",
    ReportTypes::HTML_DETAILED.upcase => "Html",
    ReportTypes::HTML_CHART.upcase => "HtmlChart",
    ReportTypes::HTML_INLINE.upcase => "HtmlInline",
    ReportTypes::HTML_INLINE_AZURE.upcase => "HtmlInline_AzurePipelines",
    ReportTypes::HTML_INLINE_AZURE_DARK.upcase => "HtmlInline_AzurePipelines_Dark",
    ReportTypes::MHTML.upcase => "MHtml",
    ReportTypes::TEXT.upcase => "TextSummary",
    ReportTypes::COBERTURA.upcase => "Cobertura",
    ReportTypes::SONARQUBE.upcase => "SonarQube",
    ReportTypes::BADGES.upcase => "Badges",
    ReportTypes::CSV_SUMMARY.upcase => "CsvSummary",
    ReportTypes::LATEX.upcase => "Latex",
    ReportTypes::LATEX_SUMMARY.upcase => "LatexSummary",
    ReportTypes::PNG_CHART.upcase => "PngChart",
    ReportTypes::TEAM_CITY_SUMMARY.upcase => "TeamCitySummary",
    ReportTypes::LCOV.upcase => "lcov",
    ReportTypes::XML.upcase => "Xml",
    ReportTypes::XML_SUMMARY.upcase => "XmlSummary",
  }

  REPORT_GENERATOR_SETTING_PREFIX = "gcov_report_generator"

  # Build the ReportGenerator arguments.
  def args_builder(opts)
    rg_opts = get_opts(opts)
    report_type_count = 0

    args = ""
    args += "\"-reports:*.gcov\" "
    args += "\"-targetdir:\"#{GCOV_REPORT_GENERATOR_ARTIFACTS_PATH}\"\" "

    # Build the report types argument.
    args += "\"-reporttypes:"

    for report_type in opts[:gcov_reports]
      rg_report_type = REPORT_TYPE_TO_REPORT_GENERATOR_REPORT_NAME[report_type.upcase]
      if !(rg_report_type.nil?)
        args += rg_report_type + ";"
        report_type_count = report_type_count + 1
      end
    end

    # Removing trailing ';' after the last report type.
    args = args.chomp(";")

    # Append a space separator after the report type.
    args += "\" "

    # Build the source directories argument.
    args += "\"-sourcedirs:.;#{opts[:collection_paths_source].join(';')}\" "

    args += "\"-historydir:#{rg_opts[:history_directory]}\" " unless rg_opts[:history_directory].nil?
    args += "\"-plugins:#{rg_opts[:plugins]}\" " unless rg_opts[:plugins].nil?
    args += "\"-assemblyfilters:#{rg_opts[:assembly_filters]}\" " unless rg_opts[:assembly_filters].nil?
    args += "\"-classfilters:#{rg_opts[:class_filters]}\" " unless rg_opts[:class_filters].nil?
    args += "\"-filefilters:#{rg_opts[:file_filters]}\" " unless rg_opts[:file_filters].nil?
    args += "\"-verbosity:#{rg_opts[:verbosity]}\" " unless rg_opts[:verbosity].nil?
    args += "\"-tag:#{rg_opts[:tag]}\" " unless rg_opts[:tag].nil?
    args += "\"settings:createSubdirectoryForAllReportTypes=true\" " unless report_type_count <= 1
    args += "\"settings:numberOfReportsParsedInParallel=#{rg_opts[:num_parallel_threads]}\" " unless rg_opts[:num_parallel_threads].nil?
    args += "\"settings:numberOfReportsMergedInParallel=#{rg_opts[:num_parallel_threads]}\" " unless rg_opts[:num_parallel_threads].nil?

    # Append custom arguments.
    for custom_arg in rg_opts[:custom_args]
      args += "\"#{custom_arg}\" " unless custom_arg.nil? || custom_arg.empty?
    end

    return args
  end


  # Get the ReportGenerator options from the project options.
  def get_opts(opts)
    return opts[REPORT_GENERATOR_SETTING_PREFIX.to_sym]
  end


  # Run ReportGenerator with the given arguments.
  def run(args)
    command = @tool_executor.build_command_line(TOOLS_GCOV_REPORTGENERATOR_REPORT, [], args)

    return @tool_executor.exec( command )
  end


  # Run gcov with the given arguments.
  def run_gcov(args)
    command = @tool_executor.build_command_line(TOOLS_GCOV_REPORT, [], args)

    return @tool_executor.exec( command )
  end

end
