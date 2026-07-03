# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'fileutils'
require 'ceedling/constants'
require 'valgrind_constants'

class Valgrind < Plugin

  def setup
    @memory_errors   = 0
    @tests_processed = 0
    @mutex = Mutex.new()

    @result_list = []

    # Validate the Valgrind tool upfront
    @ceedling[:tool_validator].validate(
      tool: TOOLS_VALGRIND,
      boom: true
    )

    FileUtils.mkdir_p(VALGRIND_ARTIFACTS_PATH)

    # Aliases
    @configurator        = @ceedling[:configurator]
    @loginator           = @ceedling[:loginator]
    @reportinator        = @ceedling[:reportinator]
    @rake_task_invoker   = @ceedling[:rake_task_invoker]
    @plugin_manager      = @ceedling[:plugin_manager]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
  end

  def pre_test_fixture_execute(arg_hash)
    return unless arg_hash[:context] == VALGRIND_SYM

    @mutex.synchronize do
      @tests_processed += 1
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
    return unless arg_hash[:context] == VALGRIND_SYM

    result_file = arg_hash[:result_file]

    @mutex.synchronize do
      if (result_file =~ /#{PROJECT_TEST_RESULTS_PATH}/) && !@result_list.include?(result_file)
        @result_list << arg_hash[:result_file]
      end
    end

    test_name = arg_hash[:test_name]
    log_path  = File.join( VALGRIND_ARTIFACTS_PATH, "#{test_name}.log" )
    return unless File.exist?( log_path )

    log_content = File.read( log_path )
    if (m = log_content.match( /ERROR SUMMARY:\s+(\d+) errors?/ )) && m[1].to_i > 0
      @mutex.synchronize do
        @memory_errors += m[1].to_i
      end
      msg = "Valgrind detected #{pluralize(m[1].to_i, 'memory error')} in #{test_name} ➡️ see #{log_path}"
      @loginator.log( msg, Verbosity::ERRORS, LogLabels::ERROR )
      log_results()
    end
  end

  def post_build(_timestamp_s)
    return unless @rake_task_invoker.invoked?( /^#{VALGRIND_ROOT_NAME}(:|$)/ )

    # Only present plugin-based test results if raw test results disabled by a reporting plugin
    if !@configurator.plugins_display_raw_test_results
      # Assemble test results
      results = @plugin_reportinator.assemble_test_results( @result_list )

      hash = {
        context: VALGRIND_SYM,
        results: results
      }

      verbosity = (results[:counts][:failed] > 0) ? Verbosity::ERRORS : Verbosity::NORMAL

      # Print unit test suite results
      @plugin_reportinator.run_test_results_report( hash, verbosity )
    end

    log_results()
    if @configurator.valgrind_fail_build && @memory_errors > 0
      msg = "Valgrind detected #{pluralize(@memory_errors, 'memory error')} across #{pluralize(@tests_processed, 'test')}"
      @plugin_manager.register_build_failure( VALGRIND_SYM, msg )
    end
  end

  private

  def log_results
    @mutex.synchronize do
      if @tests_processed > 0
        msg = "\nWrote #{pluralize(@tests_processed, 'Valgrind report')} to #{VALGRIND_ARTIFACTS_PATH}/"
        @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
      end
    end
  end

  def pluralize(count, word)
    "#{count} #{word}#{count == 1 ? '' : 's'}"
  end

end
