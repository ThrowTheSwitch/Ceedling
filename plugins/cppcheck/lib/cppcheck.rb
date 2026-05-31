require 'ceedling/constants'
require 'ceedling/plugin'

require 'cppcheck_constants'
require 'cppcheck_reports'

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
    
    evaluate_config()
    
    @tool_validator.validate(
      tool: TOOLS_CPPCHECK,
      boom: true
    )
    
    @configurator.replace_flattened_config(
      collect_suppressions(@configurator.project_config_hash)
    )
    
    @reports = {}
    @config[:reports].uniq.map(&:to_sym).each do |type|
      next if @reports.key?(type)
      if type == :html
        @reports[:xml] ||= new_report(:xml)
        @reports[:html] = new_report(:html, @reports[:xml].artifact_filepath)
      elsif (report = new_report(type))
        @reports[type] = report
      end
    end
  end
  
  def generate_reports()
    using_project_file = !(@config[:project].nil? || @config[:project].empty?)
    include_paths = using_project_file ? [] : COLLECTION_PATHS_INCLUDE
    source_paths = using_project_file ? [] : COLLECTION_PATHS_SOURCE
    
    opts = build_project_opts()
    args = [
      include_paths,
      source_paths
    ]
    
    reports_to_do = if @reports.key?(:html)
        @reports.values_at(:xml, :html) + @reports.except(:xml, :html).values
      else
        @reports.values
      end
    reports_to_do.each {|report| report.generate(opts, *args)}
  end
  
  def analyze_file(filepath)
    opts = build_file_opts()
    args = [
      COLLECTION_PATHS_INCLUDE,
      filepath
    ]
    
    @loginator.log("Running Cppcheck on file #{filepath} ...", Verbosity::NORMAL)
    results = run_tool(TOOLS_CPPCHECK, opts, *args)
    @loginator.log(results[:output], Verbosity::COMPLAIN, LogLabels::NONE)
  end
  
  private
  
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
        all_suppressions.include(File.join(path, '*.xml'))
        all_suppressions.include(File.join(
          path,
          "*#{in_hash[:extension_cppcheck]}")
        )
      end
    end
    
    @file_path_collection_utils.revise_filelist(
      all_suppressions,
      in_hash[:files_cppcheck]
    )
    
    return {
      :collection_all_cppcheck => all_suppressions
    }
  end
  
  def new_report(report_type, *report_args, boom: false)
    case report_type
    when :html  then return CppcheckHtmlReport.new(@ceedling, @config, *report_args)
    when :sarif then return CppcheckSarifReport.new(@ceedling, @config, *report_args)
    when :text  then return CppcheckTextReport.new(@ceedling, @config, *report_args)
    when :xml   then return CppcheckXmlReport.new(@ceedling, @config, *report_args)
    else
      @loginator.log("Report '#{report_type}' is not supported.", Verbosity::ERRORS)
      raise CeedlingException.new("Invalid Cppcheck report type has been requested.") if boom
    end
  end
  
  def build_common_opts()
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
      opts << option
    end
    
    return opts
  end
  
  def build_project_opts()
    opts = build_common_opts()
    
    opts << "--cppcheck-build-dir=#{CPPCHECK_BUILD_PATH}"
    opts << '--enable=all'
    
    unless @config[:project].nil? || @config[:project].empty?
      opts << "--project=#{@config[:project]}"
    end
    
    return opts
  end
  
  def build_file_opts()
    opts = build_common_opts()
    
    unless @config[:enable_checks].nil? || @config[:enable_checks].empty?
      opts << "--enable=#{@config[:enable_checks].join(',')}"
    end
    
    return opts
  end
  
  def run_tool(tool, opts, *args)
    command = @tool_executor.build_command_line(
      tool,
      opts,
      *args
    )
    @loginator.log("Command: #{command}", Verbosity::DEBUG)
    results = @tool_executor.exec(command)
    return results
  end
end

# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  if @ceedling[:task_invoker].invoked?(/^#{CPPCHECK_TASK_ROOT}/)
    @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash)
  end
}
