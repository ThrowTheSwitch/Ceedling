require 'ceedling/constants'
require 'ceedling/plugin'

require 'cppcheck_constants'

class Cppcheck < Plugin
  def setup
    @cacheinator = @ceedling[:cacheinator]
    @configurator = @ceedling[:configurator]
    @file_path_collection_utils = @ceedling[:file_path_collection_utils]
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator = @ceedling[:loginator]
    @setupinator = @ceedling[:setupinator]
    @system_wrapper = @ceedling[:system_wrapper]
    @tool_executor = @ceedling[:tool_executor]
    @tool_validator = @ceedling[:tool_validator]

    @config = @setupinator.config_hash[CPPCHECK_SYM]

    validate_enabled_reports()
    evaluate_config()

    if @config[:reports].include?(CppcheckReportTypes::HTML)
      @tool_validator.validate(
        tool: TOOLS_CPPCHECK_HTMLREPORT,
        boom: true
      )
    end

    @configurator.replace_flattened_config(
      collect_suppressions(@configurator.project_config_hash)
    )

    @text_artifact_filepath = form_text_artifact_filepath(
      @config[:text_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_TEXT
    )

    @sarif_artifact_filepath = form_sarif_artifact_filepath(
      @config[:sarif_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_SARIF
    )

    @xml_artifact_filepath = form_xml_artifact_filepath(
      @config[:xml_artifact_filename] || CPPCHECK_ARTIFACTS_FILE_XML
    )
  end

  def generate_reports()
    using_project_file = !(@config[:project].nil? || @config[:project].empty?)
    include_paths = using_project_file ? [] : COLLECTION_PATHS_INCLUDE
    source_paths = using_project_file ? [] : COLLECTION_PATHS_SOURCE

    opts = opts_builder_project()
    args = [
      include_paths,
      source_paths
    ]

    if @config[:reports].include?(CppcheckReportTypes::TEXT)
      generate_text_report(opts, *args)
    end

    if @config[:reports].include?(CppcheckReportTypes::XML)
      generate_xml_report(opts, *args)
    end

    if @config[:reports].include?(CppcheckReportTypes::HTML)
      generate_html_report(opts, *args)
    end

    if @config[:reports].include?(CppcheckReportTypes::SARIF)
      generate_sarif_report(opts, *args)
    end
  end

  def analyze_file(filepath)
    opts = opts_builder_file()
    args = [
      COLLECTION_PATHS_INCLUDE,
      filepath
    ]

    @loginator.log("Running Cppcheck on file #{filepath} ...", Verbosity::NORMAL)
    results = run(TOOLS_CPPCHECK, opts, *args)
    @loginator.log(results[:output], Verbosity::COMPLAIN, LogLabels::NONE)
  end

  private

  def validate_enabled_reports(boom:false)
    all_valid = @config[:reports].all? do |report|
      valid = CppcheckReportTypes::is_supported?(report)
      @loginator.log(
        "Report '#{report}' is not supported.",
        Verbosity::ERRORS
      ) unless valid
      valid
    end

    if boom and !all_valid
      raise CeedlingException.new("Not supported reports have been requested.")
    end
  end

  def traverse_config_eval_strings(config)
    case config
      when String
        if (config =~ PATTERNS::RUBY_STRING_REPLACEMENT)
          config.replace(@system_wrapper.module_eval(config))
        end
      when Array
        if config.all? {|item| item.is_a?(String)}
          config.each do |item|
            if (item =~ PATTERNS::RUBY_STRING_REPLACEMENT)
              item.replace(@system_wrapper.module_eval(item))
            end
          end
        end
      when Hash
        config.each_value {|value| traverse_config_eval_strings(value)}
      end
  end

  def evaluate_config()
    @config.each_value do |item|
      traverse_config_eval_strings(item)
    end
  end

  def collect_suppressions(in_hash)
    all_suppressions = @file_wrapper.instantiate_file_list

    in_hash[:collection_paths_cppcheck].each do |path|
      if @file_wrapper.exist?(path) && !@file_wrapper.directory?(path)
        all_suppressions.include(path)
      else
        all_suppressions.include(File.join(path, '*.xml') )
        all_suppressions.include(File.join(
          path,
          "*#{in_hash[:extension_cppcheck]}")
        )
      end
    end

    @file_path_collection_utils.revise_filelist(
      all_suppressions,in_hash[:files_cppcheck]
    )

    return {
      :collection_all_cppcheck => all_suppressions
    }
  end

  def form_text_artifact_filepath(filename)
    return File.join(
      CPPCHECK_ARTIFACTS_PATH,
      File.basename(filename).ext('.txt')
    )
  end

  def form_sarif_artifact_filepath(filename)
    return File.join(
      CPPCHECK_ARTIFACTS_PATH,
      File.basename(filename).ext('.sarif')
    )
  end

  def form_xml_artifact_filepath(filename)
    return File.join(
      CPPCHECK_ARTIFACTS_PATH,
      File.basename(filename).ext('.xml')
    )
  end

  def opts_builder_common()
    opts = []

    unless @config[:platform].nil? || @config[:platform].empty?
      opts << "--platform=#{@config[:platform]}"
    end

    unless @config[:template].nil? || @config[:template].empty?
      opts << "--template=#{@config[:template]}"
    end

    unless @config[:standard].nil? || @config[:standard].empty?
      opts << "--std=#{@config[:standard]}"
    end

    opts << "--inline-suppr" if @config[:inline_suppressions] == true

    unless @config[:check_level].nil? || @config[:check_level].empty?
      opts << "--check-level=#{@config[:check_level]}"
    end

    unless @config[:disable_checks].nil? || @config[:disable_checks].empty?
      opts << "--disable=#{@config[:disable_checks].join(',')}"
    end

    @config[:addons]&.each do |addon|
      opts << "--addon=#{addon}"
    end

    @config[:includes]&.each do |include|
      opts << "--include=#{include}"
    end

    @config[:excludes]&.each do |exclude|
      opts << "-i#{exclude}"
    end

    @config[:libraries]&.each do |library|
      opts << "--library=#{library}"
    end

    @config[:rules]&.each do |rule|
      opts << "--rule=#{rule}"
    end

    COLLECTION_ALL_CPPCHECK.each do |suppression|
      option = suppression.end_with?('.xml')? '--suppress-xml' : '--suppressions-list'
      opts << "#{option}=#{suppression}"
    end

    @config[:suppressions]&.each do |suppression|
      opts << "--suppress=#{suppression}"
    end

    @config[:defines]&.each do |define|
      opts << "-D#{define}"
    end

    @config[:undefines]&.each do |undefine|
      opts << "-U#{undefine}"
    end

    @config[:options]&.each do |option|
      opts << "#{option}"
    end

    return opts
  end

  def opts_builder_project()
    opts = opts_builder_common();

    opts << "--cppcheck-build-dir=#{CPPCHECK_BUILD_PATH}"
    opts << '--enable=all'

    unless @config[:project].nil? || @config[:project].empty?
      opts << "--project=#{@config[:project]}"
    end

    return opts
  end

  def opts_builder_file()
    opts = opts_builder_common()

    unless @config[:enable_checks].nil? || @config[:enable_checks].empty?
      opts << "--enable=#{@config[:enable_checks].join(',')}"
    end

    return opts
  end

  def opts_builder_text()
    opts = [
      "--output-file=#{@text_artifact_filepath}"
    ]

    return opts
  end

  def opts_builder_sarif()
    opts = [
      "--output-file=#{@sarif_artifact_filepath}",
      "--output-format=sarif"
    ]

    return opts
  end

  def opts_builder_xml()
    opts = [
      "--xml",
      "--output-file=#{@xml_artifact_filepath}"
    ]

    return opts
  end

  def opts_builder_html()
    opts = []

    opts << "--file=#{@xml_artifact_filepath}"
    opts << "--report-dir=#{CPPCHECK_ARTIFACTS_HTML_PATH}"
    opts << "--source-dir=."

    unless @config[:html_title].nil? || @config[:html_title].empty?
      opts << "--title=#{@config[:html_title]}"
    end

    return opts
  end

  def run(tool, opts, *args)
    command = @tool_executor.build_command_line(
      tool,
      opts,
      *args
    )
    @loginator.log("Command: #{command}", Verbosity::DEBUG)

    results = @tool_executor.exec(command)

    return results
  end

  def generate_text_report(opts, *args)
    opts = opts.dup()
    opts += opts_builder_text()

    @loginator.log("Creating Cppcheck text report...", Verbosity::NORMAL)
    results = run(TOOLS_CPPCHECK, opts, *args)
  end

  def generate_sarif_report(opts, *args)
    opts = opts.dup()
    opts += opts_builder_sarif()

    @loginator.log("Creating Cppcheck sarif report...", Verbosity::NORMAL)
    results = run(TOOLS_CPPCHECK, opts, *args)
  end

  def generate_xml_report(opts, *args)
    opts = opts.dup()
    opts += opts_builder_xml()

    @loginator.log("Creating Cppcheck xml report...", Verbosity::NORMAL)
    results = run(TOOLS_CPPCHECK, opts, *args)
  end

  def generate_html_report(opts, *args)
    generate_xml_report(opts, *args) unless @file_wrapper.exist?(@xml_artifact_filepath)

    @loginator.log("Creating Cppcheck html report...", Verbosity::NORMAL)
    run(TOOLS_CPPCHECK_HTMLREPORT, opts_builder_html())
  end
end

# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  if @ceedling[:task_invoker].invoked?(/^#{CPPCHECK_TASK_ROOT}/)
    @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash)
  end
}
