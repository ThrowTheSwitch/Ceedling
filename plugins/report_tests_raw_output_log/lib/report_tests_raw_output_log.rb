# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/report_log_writer_plugin'
require 'ceedling/constants'

class ReportTestsRawOutputLog < ReportLogWriterPlugin
  # `Plugin` setup()
  def setup
    super

    # @raw_output hash with default values
    @raw_output = {}
  end

  # `Plugin` build step hook
  def post_test_fixture_execute(arg_hash)
    output = extract_output( arg_hash[:shell_result][:output] )

    # Bail out early
    return if output.empty?

    # After test fixture execution, parse output, store any raw console statements
    @mutex.synchronize do
      process_output(
        arg_hash[:context],
        arg_hash[:test_name],
        output,
        @raw_output
      )
    end
  end

  # `Plugin` build step hook
  def post_build(_timestamp_s)
    # Write collected raw output to log(s)
    write_logs( @raw_output )
  end

  # `Plugin` build step hook
  def post_error(_timestamp_s)
    # Write collected raw output to log(s)
    write_logs( @raw_output )
  end

  ### Private ###

  private

  # Pick apart test executable console output to find any lines not specific to a test case
  def extract_output(raw_output)
    output = []

    raw_output.each_line do |line|
      # Skip blank lines
      next if line =~ /^\s*\n$/

      # Skip test case reporting lines
      next if line =~ /^.+:\d+:.+:(IGNORE|PASS|FAIL)/

      # Return early if we get to test results summary footer
      return output if line =~/^-+\n$/

      # Capture all other console output from the test runner, including `printf()`-style debugging statements
      output << line
    end

    return output
  end

  # Store raw output messages to hash in thread-safe manner
  def process_output(context, test, output, hash)
    # Store warning message
    hash[context] = {} if hash[context].nil?
    hash[context][test] = output
  end

  def write_logs(hash)
    flush_log(
      heading: 'Running Raw Tests Output Report',
      empty_message: 'Tests produced no extra console output.',
      empty: -> { hash.empty? }
    ) do
      hash.each do |context, tests|
        tests.each do |test, output|
          write_artifact(artifact_filepath(context, "#{test}.raw.log"), output.join)
        end
      end
    end
  end

end
