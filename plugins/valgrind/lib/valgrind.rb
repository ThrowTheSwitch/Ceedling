# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'fileutils'
require 'ceedling/constants'
require 'valgrind_constants'

class Valgrind < Plugin

  def setup
    @results = 0
    @mutex = Mutex.new()

    # Validate the Valgrind tool upfront
    @ceedling[:tool_validator].validate(
      tool: TOOLS_VALGRIND,
      boom: true
    )
    
    FileUtils.mkdir_p(VALGRIND_ARTIFACTS_PATH)

    # Aliases
    @configurator      = @ceedling[:configurator]
    @loginator         = @ceedling[:loginator]
    @reportinator      = @ceedling[:reportinator]
    @rake_task_invoker = @ceedling[:rake_task_invoker]
  end

  def pre_test_fixture_execute(arg_hash)
    return unless @rake_task_invoker.invoked?( /^#{VALGRIND_ROOT_NAME}/ )

    @mutex.synchronize do
      @results += 1
    end

    test_name = arg_hash[:test_name]
    log_path  = File.join( VALGRIND_ARTIFACTS_PATH, "#{test_name}.log" )

    # Replace the test fixture tool with a per-test valgrind wrapper.
    # Arguments come from :valgrind ↳ :arguments project config.
    # ${1} (the test executable substitution token) is always appended by the plugin, 
    # not user-visible in config.
    valgrind_args = Array( @configurator.project_config_hash[:valgrind_arguments] )
    arg_hash[:tool] = {
      :executable => TOOLS_VALGRIND[:executable],
      :name       => TOOLS_VALGRIND[:name],
      :optional   => TOOLS_VALGRIND[:optional],
      :arguments  => ["--log-file=\"#{log_path}\""] + valgrind_args + ["${1}"],
    }

    msg = "Running #{File.basename(arg_hash[:executable])} under Valgrind"
    arg_hash[:msg] = @reportinator.generate_progress( msg )
  end

  def post_test_fixture_execute(arg_hash)
    return unless @rake_task_invoker.invoked?( /^#{VALGRIND_ROOT_NAME}/ )
    return unless @configurator.project_config_hash[:valgrind_halt_on_error]

    test_name = arg_hash[:test_name]
    log_path  = File.join( VALGRIND_ARTIFACTS_PATH, "#{test_name}.log" )
    return unless File.exist?( log_path )

    log_content = File.read( log_path )
    if (m = log_content.match( /ERROR SUMMARY:\s+(\d+) errors?/ )) && m[1].to_i > 0
      raise CeedlingException.new(
        "Valgrind detected #{m[1]} memory error(s) in #{test_name} ➡️ see #{log_path}"
      )
    end
  end

  def post_build
    if @results > 0
      plural = @results == 1 ? '' : 's'
      msg = "\nWrote #{@results} Valgrind report#{plural} to #{VALGRIND_ARTIFACTS_PATH}/"
      @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
    end
  end

end
