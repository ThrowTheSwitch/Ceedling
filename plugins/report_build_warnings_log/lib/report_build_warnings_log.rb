# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'ceedling/plugins/report_log_writer_plugin'
require 'ceedling/constants'
require 'set'
require 'warning_collector'
require 'warning_reports'
require 'version'

class ReportBuildWarningsLog < ReportLogWriterPlugin

  # `Plugin` setup()
  def setup
    super

    # Each build context that ran a build step, with its warnings. A plain Hash, so
    # merely reading an absent context never adds it.
    @warnings = Hash.new

    configurator = @ceedling[:configurator]

    # The configured reports, each written as the configured filename with its own extension
    @basename = WarningReports.basename( configurator.report_build_warnings_log_filename )
    @reports  = WarningReports.load( configurator.report_build_warnings_log_reports, version: Ceedling::Version::TAG )

    # Optional patterns replace the default warning match, and excludes drop matches
    @collector   = WarningCollector.new(
      patterns: WarningCollector.compile( configurator.report_build_warnings_log_patterns, setting: ':report_build_warnings_log ↳ :patterns' ),
      excludes: WarningCollector.compile( configurator.report_build_warnings_log_excludes, setting: ':report_build_warnings_log ↳ :excludes' )
    )
  end

  # `Plugin` build step hook
  def post_mock_preprocess(arg_hash)
    # After preprocessing, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result].nil? ? '' : arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_test_preprocess(arg_hash)
    # After preprocessing, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result].nil? ? '' : arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_compile_execute(arg_hash)
    # After compiling, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result].nil? ? '' : arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_link_execute(arg_hash)
    # After linking, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result].nil? ? '' : arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_build(_timestamp_s)
    # Write collected warnings to log(s)
    write_logs
  end

  # `Plugin` build step hook
  def post_error(_timestamp_s)
    # Write collected warnings to log(s)
    write_logs
  end

  ### Private ###

  private

  # Stores each warning in the output, with its context, once per build context. A
  # header's warning repeated by every file including it is stored the first time. A
  # context is stored even without warnings, as a structured report still covers it.
  def process_output(context, output, hash)
    warnings = @collector.warnings( output )

    @mutex.synchronize do
      entry = (hash[context] ||= { collection: [], seen: Set.new })
      warnings.each do |warning|
        entry[:collection] << warning if entry[:seen].add?( @collector.identity( warning ) )
      end
    end
  end

  # Writes each configured report for each build context. A report that skips a context
  # without warnings leaves nothing to write when no context has any.
  def write_logs
    flush_log(
      heading: 'Running Warnings Report',
      empty_message: 'Build produced no warnings.',
      empty: -> { reports_for_contexts.empty? }
    ) do
      reports_for_contexts.each do |context, report, warnings|
        write_artifact( artifact_filepath( context, "#{@basename}.#{report.extension}" ), report.render( context, warnings ) )
      end
    end
  end

  def reports_for_contexts
    return @warnings.flat_map do |context, entry|
      @reports.filter_map { |report| [context, report, entry[:collection]] if report.write_empty? or entry[:collection].any? }
    end
  end

end
