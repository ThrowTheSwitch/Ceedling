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

  if File.basename(object.source) =~ /^(#{PROJECT_TEST_FILE_PREFIX}|#{CMOCK_MOCK_PREFIX}|#{GCOV_IGNORE_SOURCES.join('|')})/i
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
  def gcov_args_builder(opts)
    # Determine the Cobertura XML report file name.
    artifacts_file_cobertura = GCOV_ARTIFACTS_FILE_COBERTURA
    if !opts[:gcov_cobertura_artifact_filename].nil?
        artifacts_file_cobertura = File.join(GCOV_ARTIFACTS_PATH, opts[:gcov_cobertura_artifact_filename])
    elsif !opts[:gcov_xml_artifact_filename].nil?
        artifacts_file_cobertura = File.join(GCOV_ARTIFACTS_PATH, opts[:gcov_xml_artifact_filename])
    end

    # Determine the SonarQube XML report file name.
    artifacts_file_sonarqube = GCOV_ARTIFACTS_FILE_SONARQUBE
    if !opts[:gcov_sonarqube_artifact_filename].nil?
        artifacts_file_sonarqube = File.join(GCOV_ARTIFACTS_PATH, opts[:gcov_sonarqube_artifact_filename])
    end

    # Determine the JSON report file name.
    artifacts_file_json = GCOV_ARTIFACTS_FILE_JSON
    if !opts[:gcov_json_artifact_filename].nil?
        artifacts_file_json = File.join(GCOV_ARTIFACTS_PATH, opts[:gcov_json_artifact_filename])
    end

    artifacts_file_html = GCOV_ARTIFACTS_FILE_HTML
    if !opts[:gcov_html_artifact_filename].nil?
      artifacts_file_html = File.join(GCOV_ARTIFACTS_PATH, opts[:gcov_html_artifact_filename])
    end

    cobertura_xml_enabled = (!(opts[:gcov_xml_report].nil?) && opts[:gcov_xml_report]) || (!(opts[:gcov_cobertura_report].nil?) && opts[:gcov_cobertura_report])
    sonarqube_enabled = !(opts[:gcov_sonarqube_report].nil?) && opts[:gcov_sonarqube_report]
    json_enabled = !(opts[:gcov_json_report].nil?) && opts[:gcov_json_report]
    html_enabled = opts[:gcov_html_report].nil? || opts[:gcov_html_report] # Default to enabled.

    args = ""
    args += "--root \"#{opts[:gcov_report_root] || '.'}\" "
    args += "--filter \"#{opts[:gcov_report_include]}\" " unless opts[:gcov_report_include].nil?
    args += "--exclude \"#{opts[:gcov_report_exclude] || GCOV_FILTER_EXCLUDE}\" "
    args += "--gcov-filter \"#{opts[:gcov_gcov_filter]}\" " unless opts[:gcov_gcov_filter].nil?
    args += "--gcov-exclude \"#{opts[:gcov_gcov_exclude]}\" " unless opts[:gcov_gcov_exclude].nil?
    args += "--exclude-directories \"#{opts[:gcov_exclude_directories]}\" " unless opts[:gcov_exclude_directories].nil?
    args += "--branches " if opts[:gcov_branches].nil? || opts[:gcov_branches] # Default to enabled.
    args += "--sort-uncovered " if !(opts[:gcov_sort_uncovered].nil?) && opts[:gcov_sort_uncovered]
    args += "--sort-percentage " if ((opts[:gcov_sort_percentage].nil?) || opts[:gcov_sort_percentage]) # Default to enabled.
    args += "--print-summary " if !(opts[:gcov_print_summary].nil?) && opts[:gcov_print_summary]
    args += "--gcov-executable \"#{opts[:gcov_gcov_executable]}\"" unless opts[:gcov_gcov_executable].nil?
    args += "--exclude-unreachable-branches " if !(opts[:gcov_exclude_unreachable_branches].nil?) && opts[:gcov_exclude_unreachable_branches]
    args += "--exclude-throw-branches " if !(opts[:gcov_exclude_throw_branches].nil?) && opts[:gcov_exclude_throw_branches]
    args += "--ignore-parse-errors " if !(opts[:gcov_ignore_parse_errors].nil?) && opts[:gcov_ignore_parse_errors]
    args += "--keep " if !(opts[:gcov_keep].nil?) && opts[:gcov_keep]
    args += "--delete " if !(opts[:gcov_delete].nil?) && opts[:gcov_delete]
    args += "-j #{opts[:gcov_parallel]} " if !(opts[:gcov_parallel].nil?) && (opts[:gcov_parallel].is_a? Integer)
    [:gcov_fail_under_line, :gcov_fail_under_branch].each do |opt|
      args += "--#{opt.to_s.gsub('_','-').sub(/:?gcov-/,'')} #{opts[opt]} " unless opts[opt].nil?
    end

    if cobertura_xml_enabled
      args += "--xml \"#{artifacts_file_cobertura}\" "
      args += "--xml-pretty " if !(opts[:gcov_xml_pretty].nil?) && opts[:gcov_xml_pretty] || (!(opts[:gcov_cobertura_pretty].nil?) && opts[:gcov_cobertura_pretty])
    end

    if sonarqube_enabled
      args += "--sonarqube \"#{artifacts_file_sonarqube}\" "
    end

    if json_enabled
      # Note: In gcovr 4.2, the JSON report is output only if the --output option is specified.
      # Maybe we can remove --output in the future.
      args += "--json --output \"#{artifacts_file_json}\" "
      args += "--json-pretty " if !(opts[:gcov_json_pretty].nil?) && opts[:gcov_json_pretty]
    end

    if html_enabled
      args += "--html-details " if !(opts[:gcov_html_report_type].nil?) && (opts[:gcov_html_report_type] == 'detailed')
      args += "--html-title \"#{opts[:gcov_html_title]}\" " unless opts[:gcov_html_title].nil?
      args += "--html-absolute-paths " if !(opts[:gcov_html_absolute_paths].nil?) && opts[:gcov_html_absolute_paths]
      args += "--html-encoding \"#{opts[:gcov_html_encoding]}\" " unless opts[:gcov_html_encoding].nil?
      [:gcov_html_medium_threshold, :gcov_html_high_threshold].each do |opt|
        args += "--#{opt.to_s.gsub('_','-').sub(/:?gcov-/,'')} #{opts[opt]} " unless opts[opt].nil?
      end
      args += "--html \"#{artifacts_file_html}\" "
    end

    return args
  end

  desc "Create gcov code coverage html/xml/json report(s). (Note: Must run 'ceedling gcov' first)."
  task GCOV_SYM do

    opts = @ceedling[:configurator].project_config_hash
    args = gcov_args_builder(opts)

    if opts[:gcov_html_report].nil?
      puts "In your project.yml, define: \n\n:gcov:\n  :html_report:\n\n to true or false to refine this feature."
      puts "For now, assumimg you want an html report generated."
      html_enabled = true
    else
      html_enabled = opts[:gcov_html_report]
    end

    if opts[:gcov_xml_report].nil? && opts[:gcov_cobertura_report].nil?
      puts "In your project.yml, define: \n\n:gcov:\n  :xml_report:\n\n to true or false to refine this feature."
      puts "For now, assumimg you do not want a Cobertura xml report generated."
      cobertura_xml_enabled = false
    elsif !(opts[:gcov_xml_report].nil?)
      cobertura_xml_enabled = opts[:gcov_xml_report]
    else
      cobertura_xml_enabled = opts[:gcov_cobertura_report]
    end

    if !File.directory? GCOV_ARTIFACTS_PATH
      FileUtils.mkdir_p GCOV_ARTIFACTS_PATH
    end

    print "Creating gcov results report(s) in '#{GCOV_ARTIFACTS_PATH}'... "
    STDOUT.flush
    command = @ceedling[:tool_executor].build_command_line(TOOLS_GCOV_POST_REPORT, [], args)
    @ceedling[:tool_executor].exec(command[:line], command[:options])
    puts "Done."
  end
end
