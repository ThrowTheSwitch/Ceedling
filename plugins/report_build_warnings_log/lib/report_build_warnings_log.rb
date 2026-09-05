# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'ceedling/plugins/report_log_writer_plugin'
require 'ceedling/constants'

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

  # Extract warning messages and store to hash in thread-safe manner.
  # Keeps only the line(s) that themselves look like a warning -- not the
  # entire tool-output blob a build step produced -- so a log file holds
  # just the warnings a user actually asked this plugin to collect.
  def process_output(context, output, hash)
    lines = output.each_line.select { |line| line =~ /warning/i }
    return if lines.empty?

    @mutex.synchronize do
      entry = (hash[context] ||= { collection: [] })
      entry[:collection].concat(lines)
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
