directory(GCOV_BUILD_OUTPUT_PATH)
directory(GCOV_RESULTS_PATH)
directory(GCOV_ARTIFACTS_PATH)
directory(GCOV_DEPENDENCIES_PATH)

CLEAN.include(File.join(GCOV_BUILD_OUTPUT_PATH, '*'))
CLEAN.include(File.join(GCOV_RESULTS_PATH, '*'))
CLEAN.include(File.join(GCOV_ARTIFACTS_PATH, '*'))
CLEAN.include(File.join(GCOV_DEPENDENCIES_PATH, '*'))

CLOBBER.include(File.join(GCOV_BUILD_PATH, '**/*'))

rule(/#{GCOV_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_OBJECT}$/ => [
       proc do |task_name|
         @ceedling[:file_finder].find_compilation_input_file(task_name)
       end
     ]) do |object|

  if File.basename(object.source) =~ /^(#{PROJECT_TEST_FILE_PREFIX}|#{CMOCK_MOCK_PREFIX})|(#{VENDORS_FILES.map{|source| '\b' + source + '\b'}.join('|')})/
    @ceedling[:generator].generate_object_file(
      TOOLS_GCOV_COMPILER,
      OPERATION_COMPILE_SYM,
      GCOV_SYM,
      object.source,
      object.name,
      @ceedling[:file_path_utils].form_test_build_list_filepath(object.name)
    )
  else
    @ceedling[GCOV_SYM].generate_coverage_object_file(object.source, object.name)
  end
end

rule(/#{GCOV_BUILD_OUTPUT_PATH}\/#{'.+\\' + EXTENSION_EXECUTABLE}$/) do |bin_file|
  lib_args = @ceedling[:test_invoker].convert_libraries_to_arguments()

  @ceedling[:generator].generate_executable_file(
    TOOLS_GCOV_LINKER,
    GCOV_SYM,
    bin_file.prerequisites,
    bin_file.name,
    lib_args,
    @ceedling[:file_path_utils].form_test_build_map_filepath(bin_file.name)
  )
end

rule(/#{GCOV_RESULTS_PATH}\/#{'.+\\' + EXTENSION_TESTPASS}$/ => [
       proc do |task_name|
         @ceedling[:file_path_utils].form_test_executable_filepath(task_name)
       end
     ]) do |test_result|
  @ceedling[:generator].generate_test_results(TOOLS_GCOV_FIXTURE, GCOV_SYM, test_result.source, test_result.name)
end

rule(/#{GCOV_DEPENDENCIES_PATH}\/#{'.+\\' + EXTENSION_DEPENDENCIES}$/ => [
       proc do |task_name|
         @ceedling[:file_finder].find_compilation_input_file(task_name)
       end
     ]) do |dep|
  @ceedling[:generator].generate_dependencies_file(
    TOOLS_TEST_DEPENDENCIES_GENERATOR,
    GCOV_SYM,
    dep.source,
    File.join(GCOV_BUILD_OUTPUT_PATH, File.basename(dep.source).ext(EXTENSION_OBJECT)),
    dep.name
  )
end

task directories: [GCOV_BUILD_OUTPUT_PATH, GCOV_RESULTS_PATH, GCOV_DEPENDENCIES_PATH, GCOV_ARTIFACTS_PATH]

namespace GCOV_SYM do
  task source_coverage: COLLECTION_ALL_SOURCE.pathmap("#{GCOV_BUILD_OUTPUT_PATH}/%n#{@ceedling[:configurator].extension_object}")

  desc 'Run code coverage for all tests'
  task all: [:directories] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS, GCOV_SYM)
    @ceedling[:configurator].restore_config
  end

  desc 'Run single test w/ coverage ([*] real test or source file name, no path).'
  task :* do
    message = "\nOops! '#{GCOV_ROOT_NAME}:*' isn't a real task. " \
              "Use a real test or source file name (no path) in place of the wildcard.\n" \
              "Example: rake #{GCOV_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts(message)
  end

  desc 'Run tests by matching regular expression pattern.'
  task :pattern, [:regex] => [:directories] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if test =~ /#{args.regex}/
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].setup_and_invoke(matches, GCOV_SYM, force_run: false)
      @ceedling[:configurator].restore_config
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc 'Run tests whose test path contains [dir] or [dir] substring.'
  task :path, [:dir] => [:directories] do |_t, args|
    matches = []

    COLLECTION_ALL_TESTS.each do |test|
      matches << test if File.dirname(test).include?(args.dir.tr('\\', '/'))
    end

    if !matches.empty?
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].setup_and_invoke(matches, GCOV_SYM, force_run: false)
      @ceedling[:configurator].restore_config
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests including the given path or path component.")
    end
  end

  desc 'Run code coverage for changed files'
  task delta: [:directories] do
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke(COLLECTION_ALL_TESTS, GCOV_SYM, force_run: false)
    @ceedling[:configurator].restore_config
  end

  # use a rule to increase efficiency for large projects
  # gcov test tasks by regex
  rule(/^#{GCOV_TASK_ROOT}\S+$/ => [
         proc do |task_name|
           test = task_name.sub(/#{GCOV_TASK_ROOT}/, '')
           test = "#{PROJECT_TEST_FILE_PREFIX}#{test}" unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
           @ceedling[:file_finder].find_test_from_file_path(test)
         end
       ]) do |test|
    @ceedling[:rake_wrapper][:directories].invoke
    @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
    @ceedling[:test_invoker].setup_and_invoke([test.source], GCOV_SYM)
    @ceedling[:configurator].restore_config
  end
end

if PROJECT_USE_DEEP_DEPENDENCIES
  namespace REFRESH_SYM do
    task GCOV_SYM do
      @ceedling[:configurator].replace_flattened_config(@ceedling[GCOV_SYM].config)
      @ceedling[:test_invoker].refresh_deep_dependencies
      @ceedling[:configurator].restore_config
    end
  end
end

namespace UTILS_SYM do
  UTILITY_NAME_GCOVR = "gcovr"

  REPORT_TYPE_HTML_BASIC = "HtmlBasic"
  REPORT_TYPE_HTML_DETAILED = "HtmlDetailed"
  REPORT_TYPE_TEXT = "Text"
  REPORT_TYPE_COBERTURA = "Cobertura"
  REPORT_TYPE_SONARQUBE = "SonarQube"
  REPORT_TYPE_JSON = "JSON"

  GCOVR_SETTING_PREFIX = "gcov_gcovr"


  # Get the gcovr options from the project options.
  def get_gcovr_opts(opts)
    return opts[GCOVR_SETTING_PREFIX.to_sym] || {}
  end


  # Build the gcovr report generation common arguments.
  def gcovr_args_builder_common(opts)
    gcovr_opts = get_gcovr_opts(opts)

    args = ""
    args += "--root \"#{gcovr_opts[:report_root] || '.'}\" "
    args += "--config \"#{gcovr_opts[:config_file]}\" " unless gcovr_opts[:config_file].nil?
    args += "--filter \"#{gcovr_opts[:report_include]}\" " unless gcovr_opts[:report_include].nil?
    args += "--exclude \"#{gcovr_opts[:report_exclude] || GCOV_FILTER_EXCLUDE}\" "
    args += "--gcov-filter \"#{gcovr_opts[:gcov_filter]}\" " unless gcovr_opts[:gcov_filter].nil?
    args += "--gcov-exclude \"#{gcovr_opts[:gcov_exclude]}\" " unless gcovr_opts[:gcov_exclude].nil?
    args += "--exclude-directories \"#{gcovr_opts[:exclude_directories]}\" " unless gcovr_opts[:exclude_directories].nil?
    args += "--branches " if gcovr_opts[:branches].nil? || gcovr_opts[:branches] # Defaults to enabled.
    args += "--sort-uncovered " if gcovr_opts[:sort_uncovered]
    args += "--sort-percentage " if gcovr_opts[:sort_percentage].nil? || gcovr_opts[:sort_percentage] # Defaults to enabled.
    args += "--print-summary " if gcovr_opts[:print_summary]
    args += "--gcov-executable \"#{gcovr_opts[:gcov_executable]}\" " unless gcovr_opts[:gcov_executable].nil?
    args += "--exclude-unreachable-branches " if gcovr_opts[:exclude_unreachable_branches]
    args += "--exclude-throw-branches " if gcovr_opts[:exclude_throw_branches]
    args += "--use-gcov-files " if gcovr_opts[:use_gcov_files]
    args += "--gcov-ignore-parse-errors " if gcovr_opts[:gcov_ignore_parse_errors]
    args += "--keep " if gcovr_opts[:keep]
    args += "--delete " if gcovr_opts[:delete]
    args += "-j #{gcovr_opts[:num_parallel_threads]} " if !(gcovr_opts[:num_parallel_threads].nil?) && (gcovr_opts[:num_parallel_threads].is_a? Integer)

    [:fail_under_line, :fail_under_branch, :source_encoding, :object_directory].each do |opt|
      args += "--#{opt.to_s.gsub('_','-')} #{gcovr_opts[opt]} " unless gcovr_opts[opt].nil?
    end

    return args
  end


  # Build the gcovr Cobertura XML report generation arguments.
  def gcovr_args_builder_cobertura(opts, use_output_option=false)
    gcovr_opts = get_gcovr_opts(opts)
    args = ""

    # Determine if the Cobertura XML report is enabled. Defaults to disabled.
    if opts[:gcov_xml_report] || is_report_enabled(opts, REPORT_TYPE_COBERTURA)
      # Determine the Cobertura XML report file name.
      artifacts_file_cobertura = GCOV_ARTIFACTS_FILE_COBERTURA
      if !(gcovr_opts[:cobertura_artifact_filename].nil?)
        artifacts_file_cobertura = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:cobertura_artifact_filename])
      elsif !(gcovr_opts[:xml_artifact_filename].nil?)
        artifacts_file_cobertura = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:xml_artifact_filename])
      end

      args += "--xml-pretty " if gcovr_opts[:xml_pretty] || gcovr_opts[:cobertura_pretty]
      args += "--xml #{use_output_option ? "--output " : ""} \"#{artifacts_file_cobertura}\" "
    end

    return args
  end


  # Build the gcovr SonarQube report generation arguments.
  def gcovr_args_builder_sonarqube(opts, use_output_option=false)
    gcovr_opts = get_gcovr_opts(opts)
    args = ""

    # Determine if the gcovr SonarQube XML report is enabled. Defaults to disabled.
    if is_report_enabled(opts, REPORT_TYPE_SONARQUBE)
      # Determine the SonarQube XML report file name.
      artifacts_file_sonarqube = GCOV_ARTIFACTS_FILE_SONARQUBE
      if !(gcovr_opts[:sonarqube_artifact_filename].nil?)
        artifacts_file_sonarqube = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:sonarqube_artifact_filename])
      end

      args += "--sonarqube #{use_output_option ? "--output " : ""} \"#{artifacts_file_sonarqube}\" "
    end

    return args
  end


  # Build the gcovr JSON report generation arguments.
  def gcovr_args_builder_json(opts, use_output_option=false)
    gcovr_opts = get_gcovr_opts(opts)
    args = ""

    # Determine if the gcovr JSON report is enabled. Defaults to disabled.
    if is_report_enabled(opts, REPORT_TYPE_JSON)
      # Determine the JSON report file name.
      artifacts_file_json = GCOV_ARTIFACTS_FILE_JSON
      if !(gcovr_opts[:json_artifact_filename].nil?)
        artifacts_file_json = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:json_artifact_filename])
      end

      args += "--json-pretty " if gcovr_opts[:json_pretty]
      args += "--json #{use_output_option ? "--output " : ""} \"#{artifacts_file_json}\" "
    end

    return args
  end


  # Build the gcovr HTML report generation arguments.
  def gcovr_args_builder_html(opts, use_output_option=false)
    gcovr_opts = get_gcovr_opts(opts)
    args = ""

    # Determine if the gcovr HTML report is enabled. Defaults to enabled.
    html_enabled = (opts[:gcov_html_report].nil? && opts[:gcov_reports].nil?) ||
                   opts[:gcov_html_report] ||
                   is_report_enabled(opts, REPORT_TYPE_HTML_BASIC) ||
                   is_report_enabled(opts, REPORT_TYPE_HTML_DETAILED)

    if html_enabled
      # Determine the HTML report file name.
      artifacts_file_html = GCOV_ARTIFACTS_FILE_HTML
      if !(gcovr_opts[:html_artifact_filename].nil?)
        artifacts_file_html = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:html_artifact_filename])
      end

      is_html_report_type_detailed = (opts[:gcov_html_report_type].is_a? String) && (opts[:gcov_html_report_type].casecmp("detailed") == 0)

      args += "--html-details " if is_html_report_type_detailed || is_report_enabled(opts, REPORT_TYPE_HTML_DETAILED)
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
  def make_gcovr_text_report(opts, args_common)
    gcovr_opts = get_gcovr_opts(opts)
    args_text = ""
    message_text = "Creating a gcov text report"

    if !(gcovr_opts[:text_artifact_filename].nil?)
      artifacts_file_txt = File.join(GCOV_ARTIFACTS_PATH, gcovr_opts[:text_artifact_filename])
      args_text += "--output \"#{artifacts_file_txt}\" "
      message_text += " in '#{GCOV_ARTIFACTS_PATH}'... "
    else
      message_text += "... "
    end

    print message_text
    STDOUT.flush

    # Generate the text report.
    run_gcovr(args_common + args_text)
  end


  # Returns true is the given utility is enabled, otherwise returns false.
  def is_utility_enabled(opts, utility_name)
    return !(opts.nil?) && !(opts[:gcov_utilities].nil?) && (opts[:gcov_utilities].map(&:upcase).include? utility_name.upcase)
  end


  # Returns true if the given report type is enabled, otherwise returns false.
  def is_report_enabled(opts, report_type)
    return !(opts.nil?) && !(opts[:gcov_reports].nil?) && (opts[:gcov_reports].map(&:upcase).include? report_type.upcase)
  end


  # Get the gcovr version number as components.
  # Returns [major, minor].
  def get_gcovr_version()
    gcovr_version_number_major = 0
    gcovr_version_number_minor = 0

    command = @ceedling[:tool_executor].build_command_line(TOOLS_GCOV_POST_REPORT, [], "--version")
    shell_result = @ceedling[:tool_executor].exec(command[:line], command[:options])
    version_number_match_data = shell_result[:output].match(/gcovr ([0-9]+)\.([0-9]+)/)

    if !(version_number_match_data.nil?) && !(version_number_match_data[1].nil?) && !(version_number_match_data[2].nil?)
        gcovr_version_number_major = version_number_match_data[1].to_i
        gcovr_version_number_minor = version_number_match_data[2].to_i
    end

    return gcovr_version_number_major, gcovr_version_number_minor
  end


  # Output the shell result to the console.
  def print_shell_result(shell_result)
    puts "Done in %.3f seconds." % shell_result[:time]

    if !(shell_result.nil?) && !(shell_result[:output].nil?) && (shell_result[:output].length > 0)
      puts shell_result[:output]
    end
  end


  # Run gcovr with the given arguments.
  def run_gcovr(args)
    command = @ceedling[:tool_executor].build_command_line(TOOLS_GCOV_POST_REPORT, [], args)
    shell_result = @ceedling[:tool_executor].exec(command[:line], command[:options])
    print_shell_result(shell_result)
  end


  # Generate the gcovr report(s) specified in the options.
  def make_gcovr_reports(opts)
    # Get the gcovr version number.
    gcovr_version_info = get_gcovr_version()

    # Build the common gcovr arguments.
    args_common = gcovr_args_builder_common(opts)

    if (gcovr_version_info[0] >= 4) && (gcovr_version_info[1] >= 2)
      # gcovr version 4.2 and later supports generating multiple reports with a single call.
      args = args_common
      args += gcovr_args_builder_cobertura(opts, false)
      args += gcovr_args_builder_sonarqube(opts, false)
      # Note: In gcovr 4.2, the JSON report is output only when the --output option is specified.
      # Hopefully we can remove --output after a future gcovr release.
      args += gcovr_args_builder_json(opts, true)
      # As of gcovr version 4.2, the --html argument must appear last.
      args += gcovr_args_builder_html(opts, false)

      print "Creating gcov results report(s) in '#{GCOV_ARTIFACTS_PATH}'... "
      STDOUT.flush

      # Generate the report(s).
      run_gcovr(args)
    else
      # gcovr version 4.1 and earlier supports HTML and Cobertura XML reports.
      # It does not support SonarQube and JSON reports.
      # Reports must also be generated separately.
      args_cobertura = gcovr_args_builder_cobertura(opts, true)
      args_html = gcovr_args_builder_html(opts, true)

      if args_html.length > 0
        print "Creating a gcov HTML report in '#{GCOV_ARTIFACTS_PATH}'... "
        STDOUT.flush

        # Generate the HTML report.
        run_gcovr(args_common + args_html)
      end

      if args_cobertura.length > 0
        print "Creating a gcov XML report in '#{GCOV_ARTIFACTS_PATH}'... "
        STDOUT.flush

        # Generate the Cobertura XML report.
        run_gcovr(args_common + args_cobertura)
      end
    end

    # Determine if the gcovr text report is enabled. Defaults to disabled.
    if is_report_enabled(opts, REPORT_TYPE_TEXT)
      make_gcovr_text_report(opts, args_common)
    end
  end


  desc "Create gcov code coverage html/xml/json/text report(s). (Note: Must run 'ceedling gcov' first)."
  task GCOV_SYM do
    # Get the gcov options from project.yml.
    opts = @ceedling[:configurator].project_config_hash

    # Create the artifacts output directory.
    if !File.directory? GCOV_ARTIFACTS_PATH
      FileUtils.mkdir_p GCOV_ARTIFACTS_PATH
    end

    # Remove unsupported reporting utilities.
    if !(opts[:gcov_utilities].nil?)
      opts[:gcov_utilities].reject! { |item| !([UTILITY_NAME_GCOVR].map(&:upcase).include? item.upcase) }
    end

    # Default to gcovr when no reporting utilities are specified.
    if opts[:gcov_utilities].nil? || opts[:gcov_utilities].empty?
      opts[:gcov_utilities] = [UTILITY_NAME_GCOVR]
    end

    # Default to HTML basic report when no report types are defined.
    if opts[:gcov_reports].nil? && opts[:gcov_html_report_type].nil? && opts[:gcov_xml_report].nil?
      opts[:gcov_reports] = [REPORT_TYPE_HTML_BASIC]

      puts "In your project.yml, define one or more of the"
      puts "following to specify which reports to generate."
      puts "For now, creating only an #{REPORT_TYPE_HTML_BASIC} report."
      puts ""
      puts ":gcov:"
      puts "  :reports:"
      puts "    - #{REPORT_TYPE_HTML_BASIC}"
      puts "    - #{REPORT_TYPE_HTML_DETAILED}"
      puts "    - #{REPORT_TYPE_TEXT}"
      puts "    - #{REPORT_TYPE_COBERTURA}"
      puts "    - #{REPORT_TYPE_SONARQUBE}"
      puts "    - #{REPORT_TYPE_JSON}"
      puts ""
    end

    if is_utility_enabled(opts, UTILITY_NAME_GCOVR)
      make_gcovr_reports(opts)
    end

  end
end
