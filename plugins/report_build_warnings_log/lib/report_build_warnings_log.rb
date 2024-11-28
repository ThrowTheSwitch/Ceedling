# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'ceedling/plugin'
require 'ceedling/constants'

class ReportBuildWarningsLog < Plugin
  
  # `Plugin` setup()
  def setup
    # Create structure of @warnings hash with default values
    @warnings = Hash.new() do |h,k|
      # k => :context
      h[k] = {
        collection: [],
      }
    end

    # Ceedling can run with multiple threads, provide a lock to use around @warnings
    @mutex = Mutex.new()

    # Get default (default.yml) / user-set log filename in project configuration
    @log_filename = @ceedling[:configurator].report_build_warnings_log_filename

    # Convenient instance variable references
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
  end

  # `Plugin` build step hook
  def post_mock_preprocess(arg_hash)
    # After preprocessing, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_test_preprocess(arg_hash)
    # After preprocessing, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_compile_execute(arg_hash)
    # After compiling, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_link_execute(arg_hash)
    # After linking, parse output, store warning if found
    process_output(
      arg_hash[:context],
      arg_hash[:shell_result][:output],
      @warnings
    )
  end

  # `Plugin` build step hook
  def post_build()
    # Write collected warnings to log(s)
    write_logs( @warnings, @log_filename )
  end

  # `Plugin` build step hook
  def post_error()
    # Write collected warnings to log(s)
    write_logs( @warnings, @log_filename )
  end

  ### Private ###

  private

  # Extract warning messages and store to hash in thread-safe manner
  def process_output(context, output, hash)
    # If $stderr/$stdout does not contain "warning", bail out
    return if !(output =~ /warning/i)

    # Store warning message
    @mutex.synchronize do
      hash[context][:collection] << output
    end
  end

  # Walk warnings hash and write contents to log file(s)
  def write_logs( warnings, filename )
    msg = @reportinator.generate_heading( "Running Warnings Report" )
    @loginator.log( msg )

    empty = false

    @mutex.synchronize { empty = warnings.empty? }

    if empty
      @loginator.log( "Build produced no warnings.\n" )
      return
    end

    @mutex.synchronize do
      warnings.each do |context, hash|
        log_filepath = form_log_filepath( context, filename )

        msg = @reportinator.generate_progress( "Generating artifact #{log_filepath}" )
        @loginator.log( msg )

        File.open( log_filepath, 'w' ) do |f|
          hash[:collection].each { |warning| f << warning }
        end
      end
    end

    # White space at command line after progress messages
    @loginator.log( '' )
  end

  def form_log_filepath(context, filename)
    path = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s )
    filepath = File.join(path, filename)

    # Ensure containing artifact directory exists
    @file_wrapper.mkdir( path )

    return filepath
  end
end
