# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'

class ReportTestsRawOutputLog < Plugin
  # `Plugin` setup()
  def setup
   # @raw_output hash with default values
    @raw_output = {}

    # Ceedling can run with multiple threads, provide a lock to use around @raw_output
    @mutex = Mutex.new()

    # Convenient instance variable references
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
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
  def post_build()
    # Write collected raw output to log(s)
    write_logs( @raw_output )
  end

  # `Plugin` build step hook
  def post_error()
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
    msg = @reportinator.generate_heading( "Running Raw Tests Output Report" )
    @loginator.log( msg )

    empty = false

    @mutex.synchronize { empty = hash.empty? }

    if empty
      @loginator.log( "Tests produced no extra console output.\n" )
      return
    end

    @mutex.synchronize do
      hash.each do |context, tests|
        tests.each do |test, output|
          log_filepath = form_log_filepath( context, test )

          msg = @reportinator.generate_progress( "Generating artifact #{log_filepath}" )
          @loginator.log( msg )

          File.open( log_filepath, 'w' ) do |f|
            output.each { |line| f << line }
          end
        end
      end
    end

    # White space at command line after progress messages
    @loginator.log( '' )
  end

  def form_log_filepath(context, test)
    path = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s )
    filepath = File.join(path, test + '.raw.log')

    # Ensure containing artifact directory exists
    @file_wrapper.mkdir( path )

    return filepath
  end
end
