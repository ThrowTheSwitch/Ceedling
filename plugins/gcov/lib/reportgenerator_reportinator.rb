# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'benchmark'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/file_path_utils'
require 'gcov_reportinator'

class ReportGeneratorReportinator < GcovReportinator

  NAME = 'ReportGenerator'

  def name; NAME; end

  attr_reader :artifacts_path

  def initialize(system_objects, config)
    super(config)

    @artifacts_path = GCOV_REPORT_GENERATOR_ARTIFACTS_PATH
    @summary        = ''
    @ceedling = system_objects

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
    @loginator     = @ceedling[:loginator]
    @reportinator  = @ceedling[:reportinator]
    @tool_executor = @ceedling[:tool_executor]
    @configurator  = @ceedling[:configurator]
    @batchinator   = @ceedling[:batchinator]

    # Mutex that serializes each gcov subprocess + rename pair (see run_gcov).
    @gcov_cwd_mutex = Mutex.new
  end


  # Generate the ReportGenerator report(s) specified in the options.
  # Iterate coverage results using a listing of all .gcno files beneath GCOV_BUILD_OUTPUT_PATH.
  def generate_reports(opts)
    shell_result = nil
    total_time = Benchmark.realtime do
      rg_opts = collect_reportgenerator_opts(opts)

      log_report_intentions(opts)

      gcno_exclude_regex = build_gcno_exclude_regex(rg_opts)
      generate_gcov_files(gcno_exclude_regex)
      shell_result = run_reportgenerator(opts, rg_opts)
    end

    if shell_result
      shell_result[:time] = total_time
      print_shell_exec_time(shell_result)
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

  # Map configured report types to ReportGenerator names, silently skipping unknowns.
  # Returns an array used to build both the -reporttypes: value and the report count.
  def build_report_types(opts)
    opts[:gcov_reports].filter_map { |r| REPORT_TYPE_TO_REPORT_GENERATOR_REPORT_NAME[r.upcase] }
  end


  # Build the optional ${6} argument string for ReportGenerator.
  # report_type_count drives the createSubdirectoryForAllReportTypes setting.
  def build_optional_args(rg_opts, report_type_count)
    args = ""
    args += "\"-historydir:#{rg_opts[:history_directory]}\" " unless rg_opts[:history_directory].nil?
    args += "\"-plugins:#{rg_opts[:plugins]}\" " unless rg_opts[:plugins].nil?
    args += "\"-assemblyfilters:#{rg_opts[:assembly_filters]}\" " unless rg_opts[:assembly_filters].nil?
    args += "\"-classfilters:#{rg_opts[:class_filters]}\" " unless rg_opts[:class_filters].nil?
    args += "\"-verbosity:#{rg_opts[:verbosity]}\" " unless rg_opts[:verbosity].nil?
    args += "\"-tag:#{rg_opts[:tag]}\" " unless rg_opts[:tag].nil?
    args += "\"settings:createSubdirectoryForAllReportTypes=true\" " if report_type_count > 1
    args += "\"settings:numberOfReportsParsedInParallel=#{rg_opts[:num_parallel_threads]}\" " unless rg_opts[:num_parallel_threads].nil?
    args += "\"settings:numberOfReportsMergedInParallel=#{rg_opts[:num_parallel_threads]}\" " unless rg_opts[:num_parallel_threads].nil?
    rg_opts[:custom_args].each do |custom_arg|
      args += "\"#{custom_arg}\" " unless custom_arg.nil? || custom_arg.empty?
    end
    args.strip
  end


  # Get the ReportGenerator options from the project options.
  def collect_reportgenerator_opts(opts)
    _opts = opts[REPORT_GENERATOR_SETTING_PREFIX.to_sym]

    # Auto-generate -filefilters: exclusion patterns for test paths and the build root.
    # These exclude test files and all generated/framework files from coverage reports.
    # User-provided :file_filters are placed first and take precedence.
    auto_excludes = build_filefilter_exclusions
    _opts[:file_filters] = ([_opts[:file_filters]] + auto_excludes)
      .compact.join(';').then { |s| s.empty? ? nil : s }

    # Insert an exclusion for Ceedling Partials that will merge with any other exclusions
    if @configurator.project_use_partials
      partials_exclude = '-' + PARTIAL_FILENAME_PREFIX + '*'
      _opts[:file_filters] = [_opts[:file_filters], partials_exclude].compact.join(';').then { |s| s.empty? ? nil : s }
    end

    return _opts
  end


  # Log the report generation heading and one NOTICE line per configured report type.
  def log_report_intentions(opts)
    @loginator.log( @reportinator.generate_heading("Running ReportGenerator Coverage Reports") )

    opts[:gcov_reports].each do |report|
      msg = @reportinator.generate_progress(
        "Generating #{report} coverage report in '#{GCOV_REPORT_GENERATOR_ARTIFACTS_PATH}/'"
      )
      @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
    end
  end


  # Build a Regexp that matches .gcno filepaths to be excluded from gcov processing,
  # combining user-specified patterns with internally-generated ones.
  # Returns nil when empty.
  def build_gcno_exclude_regex(rg_opts)
    gcno_exclusions = []

    # Collect user-specified coverage results exclusions.
    for gcno_exclude_expression in rg_opts[:gcov_exclude]
      next if gcno_exclude_expression.nil? || gcno_exclude_expression.empty?
      # Users may specify exclusion patterns ending in .gcov (matching gcov output files)
      # or .gcno (matching the coverage notes files we iterate). Strip either suffix —
      # both escaped regex form (\\.gcov) and plain (.gcov) — so the bare pattern remains.
      gcno_exclude_expression = gcno_exclude_expression.chomp("\\#{EXTENSION_GCOV}").chomp(EXTENSION_GCOV)
      # Strip any .gcno suffix as well; the regex built below appends \.gcno already,
      # so including it in the pattern would double it and prevent any match.
      gcno_exclude_expression = gcno_exclude_expression.chomp("\\#{EXTENSION_GCNO}").chomp(EXTENSION_GCNO)
      gcno_exclusions << gcno_exclude_expression
    end

    # Auto-generated exclusions: test files, mocks, and test runners.
    # These are never production source, so there's no need to run gcov on them.
    gcno_exclusions += build_gcno_exclusions()

    # Build a single regex from all exclusion patterns. (\/|\\\\) matches the path
    # separator preceding the filename on both Unix and Windows, which prevents a
    # fragment from accidentally matching mid-path. \.gcno anchors to the file extension.
    # nil when the list is empty so callers can skip the regex check entirely.
    gcno_exclusions.empty? ? nil :
      Regexp.new("(\/|\\\\)(#{gcno_exclusions.join('|')})\\#{EXTENSION_GCNO}")
  end


  # Run gcov on every .gcno file found beneath GCOV_BUILD_OUTPUT_PATH, skipping those
  # that match gcno_exclude_regex. Within each directory, non-partial source files are
  # processed before their partial counterparts.
  def generate_gcov_files(gcno_exclude_regex)
    source_prefix = Dir.pwd + File::SEPARATOR

    # Collect unique directories under GCOV_BUILD_OUTPUT_PATH that contain .gcno files.
    # This covers both test-specific subdirs (tested sources) and the root dir itself
    # (untested sources placed there by process_untested_sources).
    # gcov handles a missing .gcda gracefully; it produces a .gcov with 0% coverage —
    # so no .gcda guard needed.
    gcno_dirs = Dir.glob(File.join(GCOV_BUILD_OUTPUT_PATH, "**", "*#{EXTENSION_GCNO}"))
      .map { |f| File.dirname(f) }
      .uniq
      .sort

    # Pre-compute the sorted, filtered file list for each dir before dispatching.
    # filter_map drops empty dirs so Batchinator never queues no-op work items.
    work_items = gcno_dirs.filter_map do |gcno_dir|
      files = Dir.glob(File.join(gcno_dir, "*#{EXTENSION_GCNO}"))
        .reject { |f| gcno_exclude_regex && f =~ gcno_exclude_regex }
        # Sort to process non-partial source files before their partial counterparts.
        # Processing the coverage compiled version of the original source creates .gcov
        # files for more than the partial does (primarily header files),
        # but the .gcov file for the partial contains the correct coverage information.
        # So, we must process the original source first and then overwrite some of it
        # what it generates with partial .gcov generation.
        .sort_by { |f| File.basename(f).start_with?(PARTIAL_FILENAME_PREFIX) ? 1 : 0 }
      files.empty? ? nil : { gcno_dir: gcno_dir, gcno_files: files }
    end

    # Process each dir's gcov work in parallel across the thread pool. Within each dir
    # the sorted file list is walked sequentially, preserving partial/non-partial ordering.
    @batchinator.exec(workload: :compile, things: work_items) do |item|
      item[:gcno_files].each { |gcno_filepath| run_gcov(gcno_filepath, source_prefix) }
    end
  end


  # Run ReportGenerator if .gcov files are present. Returns the shell result, or nil
  # with a complaint log if no .gcov files were produced by the gcov step.
  def run_reportgenerator(opts, rg_opts)
    unless Dir.glob(File.join(GCOV_BUILD_OUTPUT_PATH, "**", "*#{EXTENSION_GCOV}")).length > 0
      @loginator.log( "No matching .gcno coverage files found", Verbosity::COMPLAIN )
      return nil
    end

    report_type_names = build_report_types(opts)
    collapsed = FilePathUtils.collapse_to_common_parents(opts[:collection_paths_source])

    command = @tool_executor.build_command_line(
      TOOLS_GCOV_REPORTGENERATOR_REPORT, [],
      "#{GCOV_BUILD_OUTPUT_PATH}/**/*#{EXTENSION_GCOV}",      # ${1} -reports:
      GCOV_REPORT_GENERATOR_ARTIFACTS_PATH,                   # ${2} -targetdir:
      report_type_names.join(';'),                            # ${3} -reporttypes:
      ".;#{collapsed.join(';')}",                             # ${4} -sourcedirs:
      # Always non-nil: collect_reportgenerator_opts unconditionally populates 
      # it with at least the build-root exclusion from build_filefilter_exclusions.
      rg_opts[:file_filters],                                 # ${5} -filefilters: 
      build_optional_args(rg_opts, report_type_names.length)  # ${6} optional args
    )

    return @tool_executor.exec( command )
  end


  # Build glob-wildcard exclusion strings for ReportGenerator's -filefilters: argument.
  # Excludes test source paths and the build root (which contains all generated and
  # framework files: mocks, test runners, Unity, CMock, etc.).
  def build_filefilter_exclusions
    data = build_exclusion_data
    patterns = []
    data[:test_paths].each do |path|
      patterns << "-./#{path}/**/*"
    end
    patterns << "-./#{data[:build_root]}/**/*"
    patterns
  end


  # Build filename-fragment patterns for the .gcno scan exclusion regex.
  # Excludes test files, generated mocks, and test runners from gcov processing.
  # The '.*' suffix handles source extensions embedded in .gcno filenames (e.g. test_foo.c.gcno).
  def build_gcno_exclusions
    data = build_exclusion_data
    # Use [^\/\\]* (no path separators) rather than .* to match filenames only.
    # Ceedling names build output dirs after test files (e.g. build/gcov/out/test_foo/),
    # so .* would greedily match test_foo/bar.c and exclude ALL production sources.
    [
      "#{data[:test_prefix]}[^\\/\\\\]*",  # test_foo.gcno
      "#{data[:mock_prefix]}[^\\/\\\\]*",  # MockBar.gcno
      "[^\\/\\\\]*_runner[^\\/\\\\]*",     # test_foo_runner.gcno
      File.basename(UNITY_C_FILE, '.*'),   # unity.gcno
      File.basename(CMOCK_C_FILE, '.*')    # cmock.gcno
    ]
  end


  # Run gcov on gcno_filepath (full path) from the unaltered working directory.
  # source_prefix is the absolute project root — passed as -s to strip absolute #line
  # directive paths to relative so gcov's -r filter accepts project sources while
  # system headers (which don't match the prefix) remain excluded.
  # gcov writes .gcov files into the CWD; this method moves each one to the same
  # directory as the .gcno file so coverage data stays co-located with its build output.
  # Non-fatal: gcov exits non-zero for a missing .gcda (untested source); continue execution.
  def run_gcov(gcno_filepath, source_prefix)
    # gcov must run in the same working directory used during compilation so it can
    # locate the .gcda data files produced at test-fixture execution time. However,
    # parallel test builds share source files (e.g. src/utils.c may be compiled into
    # every test executable that includes it), so each test's build directory holds its
    # own utils.c.gcno. When two threads call gcov concurrently on those files, both
    # write the same hash-named .gcov to the shared CWD (gcov uses --hash-filenames / -x
    # to derive output names from the source path, so identical source paths always
    # produce the same output filename). The second write clobbers the first before the
    # rename to each test's build sub-directory can complete, silently losing coverage
    # data. Serializing the exec+rename pair with a mutex eliminates the race at the cost
    # of sequentializing only this step; the per-dir glob/filter/sort work in
    # generate_gcov_files still runs in parallel across the Batchinator thread pool.
    @gcov_cwd_mutex.synchronize do
      command = @tool_executor.build_command_line(TOOLS_GCOV_REPORT, [], "\"#{gcno_filepath}\"", source_prefix)
      command[:options][:boom] = false

      shell_result = @tool_executor.exec( command )

      if shell_result[:exit_code] != 0
        @loginator.log(
          "gcov could not process #{gcno_filepath} (exit #{shell_result[:exit_code]})",
          Verbosity::COMPLAIN
        )
      end

      # gcov logs each file it creates, e.g.: Creating 'a1b2c3d4.gcov'
      # Scan for a space followed by any non-whitespace characters ending in EXTENSION_GCOV,
      # then capture any non-whitespace character immediately after the extension.
      # A space anchors the match to the start of the filename token in gcov's output.
      # If a closing character follows the extension, it is assumed to be paired with an
      # opening character directly before the filename; both are stripped, leaving only
      # the bare filename (e.g. 'file.gcov' → file.gcov).
      gcno_dir = File.dirname(gcno_filepath)

      # Find filename in `gcov` output
      shell_result[:output].scan(/ ([^\s]*#{Regexp.escape(EXTENSION_GCOV)})(\S?)/) do |gcov_token, closing_delim|
        gcov_file = closing_delim.empty? ? gcov_token : gcov_token[1..]
        dest = File.join(gcno_dir, File.basename(gcov_file))

        # Move the generated file after extracting its filename from `gcov` output
        File.rename(gcov_file, dest) if File.exist?(gcov_file) && gcov_file != dest
      end

      return shell_result
    end
  end

end
