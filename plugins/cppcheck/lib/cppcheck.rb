# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/exceptions'

require 'cppcheck_constants'
require 'cppcheck_reports'

class Cppcheck < Plugin
  def setup
    @configurator = @ceedling[:configurator]
    @file_path_collection_utils = @ceedling[:file_path_collection_utils]
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
    @system_wrapper = @ceedling[:system_wrapper]
    @ruby_expandinator = @ceedling[:ruby_expandinator]
    @tool_executor = @ceedling[:tool_executor]
    @tool_validator = @ceedling[:tool_validator]
    
    @config = @ceedling[:setupinator].config_hash[CPPCHECK_SYM]

    evaluate_config()

    validate_fail_build_severities()

    @configurator.replace_flattened_config(
      collect_suppressions(@configurator.project_config_hash)
    )

    # Reports are built lazily by build_reports. Their constructors validate the
    # tools they need, and TOOLS_CPPCHECK_HTMLREPORT is one of them. Building here
    # would make that tool a hard dependency of every build this plugin is merely
    # enabled for, rather than only a build that actually generates an HTML report.
    @reports = nil
  end

  # Confirms Cppcheck is actually installed.
  # Called externally by the plugin Rakefile's :cppcheck_deps task, which every
  # cppcheck: task depends on.
  #
  # Validation is deliberately not done in setup(). setup() runs for every Ceedling
  # command this plugin is merely enabled for, so validating there makes Cppcheck a
  # hard dependency of plain `test:all`. It also made `ceedling files:cppcheck`,
  # which only lists suppression files, require the executable.
  def validate_environment!
    @tool_validator.validate(
      tool: TOOLS_CPPCHECK,
      boom: true
    )
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
    
    reports = build_reports()

    # Cppcheck only runs as part of generating a report. With no report configured
    # this task analyzed nothing and said nothing, which reads like a successful run.
    if reports.empty?
      @loginator.log(
        "No Cppcheck reports are configured, so no analysis ran.\n" \
        "Add a report to :cppcheck ↳ :reports, or enable :cppcheck ↳ :fail_build.",
        Verbosity::COMPLAIN,
        LogLabels::WARNING
      )
      return
    end

    reports_to_do = if reports.key?(:html)
        reports.values_at(:xml, :html) + reports.except(:xml, :html).values
      else
        reports.values
      end
    reports_to_do.each {|report| report.generate(opts, *args)}

    report_findings( reports[:xml] )
  end
  
  def analyze_file(filepath)
    opts = build_file_opts()
    args = [
      COLLECTION_PATHS_INCLUDE,
      filepath
    ]
    
    msg = @reportinator.generate_progress( "Running Cppcheck on file #{filepath}" )
    @loginator.log( msg, Verbosity::NORMAL)
    results = run_tool(TOOLS_CPPCHECK, opts, *args)
    @loginator.log(results[:output], Verbosity::COMPLAIN, LogLabels::NONE)
  end
  
  private

  # Builds the configured reports, memoized.
  #
  # :fail_build implies an XML report. Findings are counted from cppcheck's own XML
  # output, so that report has to exist. This mirrors how :html already implies :xml.
  def build_reports()
    return @reports unless @reports.nil?

    @reports = {}

    types = @config[:reports].uniq.map(&:to_sym)
    types << :xml if fail_build_enabled? and !types.include?(:xml)

    types.each do |type|
      next if @reports.key?(type)
      if type == :html
        @reports[:xml] ||= new_report(:xml)
        @reports[:html] = new_report(:html, @reports[:xml].artifact_filepath)
      elsif (report = new_report(type))
        @reports[type] = report
      end
    end

    return @reports
  end

  def fail_build_enabled?
    return @config[:fail_build] == true
  end

  def fail_build_severities
    return Array( @config[:fail_build_severities] ).map(&:to_s)
  end

  # Rejects an unrecognized :fail_build_severities value at setup rather than letting
  # it silently never match a finding.
  def validate_fail_build_severities()
    unrecognized = fail_build_severities - CPPCHECK_SEVERITIES

    return if unrecognized.empty?

    list = CPPCHECK_SEVERITIES.map { |severity| "'#{severity}'" }.join(', ')
    msg = "Plugin configuration :cppcheck ↳ :fail_build_severities ➡️ " \
          "#{unrecognized.map(&:inspect).join(', ')} not recognized. Valid severities are {#{list}}."
    raise CeedlingException.new(msg)
  end

  # Tallies findings from the XML report and reports them.
  #
  # Cppcheck exits zero even when it finds defects, so its exit code carries no
  # signal. The XML report is the only machine-readable record of what was found.
  def report_findings(xml_report)
    return if xml_report.nil?

    counts = tally_findings( xml_report.artifact_filepath )
    return if counts.nil?

    if counts.empty?
      @loginator.log( "Cppcheck found no issues.", Verbosity::NORMAL )
    else
      summary = counts.sort.map { |severity, count| "#{count} #{severity}" }.join(', ')
      @loginator.log( "Cppcheck findings: #{summary}", Verbosity::NORMAL )
    end

    return unless fail_build_enabled?

    failing = counts.select { |severity, _| fail_build_severities.include?( severity ) }
    return if failing.empty?

    total  = failing.values.sum
    detail = failing.sort.map { |severity, count| "#{count} #{severity}" }.join(', ')

    @ceedling[:plugin_manager].register_build_failure(
      CPPCHECK_SYM,
      "Cppcheck found #{total} #{total == 1 ? 'finding' : 'findings'} " \
      "matching :cppcheck ↳ :fail_build_severities (#{detail}). " \
      "See the report in #{CPPCHECK_ARTIFACTS_PATH}."
    )

    fail_build()
  end

  # Surfaces a registered failure and sets a non-zero exit code.
  #
  # Ceedling's end-of-run handler prints registered plugin failures and fails the
  # build only for namespaces it treats as build tasks. It identifies those by
  # scanning Rake files for test and release pipeline invocations. A cppcheck: task
  # drives neither, so a failure registered above would otherwise never reach the
  # user and never change the exit code.
  def fail_build()
    @ceedling[:plugin_manager].print_plugin_failures
    @ceedling[:application].register_build_failure
  end

  # Returns a severity => count hash, or nil when the report could not be read.
  def tally_findings(filepath)
    unless @file_wrapper.exist?( filepath )
      @loginator.log(
        "Cppcheck wrote no XML report at #{filepath}. Findings could not be counted.",
        Verbosity::COMPLAIN,
        LogLabels::WARNING
      )
      return nil
    end

    counts = Hash.new(0)

    # One <error> element per finding, each carrying a severity attribute.
    @file_wrapper.read( filepath ).scan( /<error\b[^>]*\bseverity="([^"]+)"/ ) do |match|
      counts[ match[0] ] += 1
    end

    return counts
  end

  def traverse_config_eval_strings(config)
    case config
      when String
        config.replace(@ruby_expandinator.expand(config, source: "cppcheck plugin configuration"))
      when Array
        # Each String element is expanded on its own. Requiring every element to be a
        # String meant one non-String entry silently disabled expansion for all of them.
        config.each do |item|
          next unless item.is_a?(String)
          item.replace(@ruby_expandinator.expand(item, source: "cppcheck plugin configuration"))
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
        # A path that does not exist globs to nothing. Warn rather than leave a typo
        # looking identical to a directory holding no suppression files.
        unless @file_wrapper.exist?(path)
          @loginator.log(
            "Cppcheck suppressions path '#{path}' does not exist. No suppressions collected from it.",
            Verbosity::COMPLAIN,
            LogLabels::WARNING
          )
        end

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


