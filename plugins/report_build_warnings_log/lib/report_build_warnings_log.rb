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

class ReportBuildWarningsLog < ReportLogWriterPlugin

  # `Plugin` setup()
  def setup
    super

    # Plain Hash -- populated only at write time (process_output), never by
    # merely reading an absent context, so `.empty?` stays a trustworthy
    # "have we collected anything at all?" check.
    @warnings = Hash.new

    # Get default (default.yml) / user-set log filename in project configuration
    @log_filename = @ceedling[:configurator].report_build_warnings_log_filename

    # Optional patterns replace the default warning match, and excludes drop matches
    configurator = @ceedling[:configurator]
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
  # header's warning repeated by every file including it is stored the first time.
  def process_output(context, output, hash)
    warnings = @collector.warnings( output )
    return if warnings.empty?

    @mutex.synchronize do
      entry = (hash[context] ||= { collection: [], seen: Set.new })
      warnings.each do |warning|
        entry[:collection] << warning if entry[:seen].add?( @collector.identity( warning ) )
      end
    end
  end

  # Walk warnings hash and write contents to log file(s)
  def write_logs
    flush_log(
      heading: 'Running Warnings Report',
      empty_message: 'Build produced no warnings.',
      empty: -> { @warnings.empty? }
    ) do
      @warnings.each do |context, hash|
        write_artifact(artifact_filepath(context, @log_filename), hash[:collection].join)
      end
    end
  end

end
