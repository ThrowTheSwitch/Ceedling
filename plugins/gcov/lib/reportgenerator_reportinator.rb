require 'benchmark'
require 'reportinator_helper'

class ReportGeneratorReportinator

  def initialize(system_objects)
    @ceedling = system_objects
    @reportinator_helper = ReportinatorHelper.new
  end


  # Generate the ReportGenerator report(s) specified in the options.
  def make_reports(opts)
    shell_result = nil
    total_time = Benchmark.realtime do
      rg_opts = get_opts(opts)

      print "Creating gcov results report(s) with ReportGenerator in '#{GCOV_REPORT_GENERATOR_PATH}'... "
      STDOUT.flush

      # Cleanup any existing .gcov files to avoid reporting old coverage results.
      for gcov_file in Dir.glob("*.gcov")
        File.delete(gcov_file)
      end

      # Avoid running gcov on the mock, test, unity, and cexception gcov notes files to save time.
      gcno_exclude_regex = /(\/|\\)(#{opts[:cmock_mock_prefix]}.*|#{opts[:project_test_file_prefix]}.*|#{VENDORS_FILES.join('|')})\.gcno/

      # Generate .gcov files by running gcov on gcov notes files (*.gcno).
      for gcno_filepath in Dir.glob(File.join(GCOV_BUILD_PATH, "**", "*.gcno"))
        match_data = gcno_filepath.match(gcno_exclude_regex)
        if match_data.nil? || (match_data[1].nil? && match_data[1].nil?)
          run_gcov("-b -c -r -x \"#{gcno_filepath}\"")
        end
      end

      if Dir.glob("*.gcov").length > 0
        # Build the command line arguments.
        args = args_builder(opts)

        # Generate the report(s).
        shell_result = run(args)
      else
        puts "\nWarning: No matching .gcno coverage files found."
      end

      # Cleanup .gcov files.
      for gcov_file in Dir.glob("*.gcov")
        File.delete(gcov_file)
      end
    end

    if shell_result
      shell_result[:time] = total_time
      @reportinator_helper.print_shell_result(shell_result)
    end
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

    args = ""
    args += "\"-reports:*.gcov\" "
    args += "\"-targetdir:\"#{GCOV_REPORT_GENERATOR_PATH}\"\" "

    # Build the report types argument.
    if !(opts.nil?) && !(opts[:gcov_reports].nil?) && !(opts[:gcov_reports].empty?)
      args += "\"-reporttypes:"

      for report_type in opts[:gcov_reports]
        rg_report_type = REPORT_TYPE_TO_REPORT_GENERATOR_REPORT_NAME[report_type.upcase]
        if !(rg_report_type.nil?)
          args += rg_report_type + ";"
        end
      end

      # Removing trailing ';' after the last report type.
      args = args.chomp(";")

      # Append a space seperator after the report type.
      args += "\" "
    end

    # Build the source directories argument.
    args += "\"-sourcedirs:.;"
    if !(opts[:collection_paths_source].nil?)
      args += opts[:collection_paths_source].join(';')
    end
    args = args.chomp(";")
    args += "\" "

    args += "\"-historydir:#{rg_opts[:history_directory]}\" " unless rg_opts[:history_directory].nil?
    args += "\"-plugins:#{rg_opts[:plugins]}\" " unless rg_opts[:plugins].nil?
    args += "\"-assemblyfilters:#{rg_opts[:assembly_filters]}\" " unless rg_opts[:assembly_filters].nil?
    args += "\"-classfilters:#{rg_opts[:class_filters]}\" " unless rg_opts[:class_filters].nil?
    file_filters = rg_opts[:file_filters] || @ceedling[:tool_executor_helper].osify_path_separators(GCOV_REPORT_GENERATOR_FILE_FILTERS)
    args += "\"-filefilters:#{file_filters}\" "
    args += "\"-verbosity:#{rg_opts[:verbosity] || "Warning"}\" "
    args += "\"-tag:#{rg_opts[:tag]}\" " unless rg_opts[:tag].nil?

    return args
  end


  # Get the ReportGenerator options from the project options.
  def get_opts(opts)
    return opts[REPORT_GENERATOR_SETTING_PREFIX.to_sym] || {}
  end


  # Run ReportGenerator with the given arguments.
  def run(args)
    command = @ceedling[:tool_executor].build_command_line(TOOLS_GCOV_REPORT_GENERATOR_POST_REPORT, [], args)
    return @ceedling[:tool_executor].exec(command[:line], command[:options])
  end


  # Run gcov with the given arguments.
  def run_gcov(args)
    command = @ceedling[:tool_executor].build_command_line(TOOLS_GCOV_GCOV_POST_REPORT, [], args)
    return @ceedling[:tool_executor].exec(command[:line], command[:options])
  end

end
