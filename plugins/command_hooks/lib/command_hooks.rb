# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'
class CommandHooks < Plugin

  attr_reader :config

  def setup
    @config = {
      :pre_mock_preprocess       => ((defined? TOOLS_PRE_MOCK_PREPROCESS)       ? TOOLS_PRE_MOCK_PREPROCESS       : nil ),
      :post_mock_preprocess      => ((defined? TOOLS_POST_MOCK_PREPROCESS)      ? TOOLS_POST_MOCK_PREPROCESS      : nil ),
      :pre_test_preprocess       => ((defined? TOOLS_PRE_TEST_PREPROCESS)       ? TOOLS_PRE_TEST_PREPROCESS       : nil ),
      :post_test_preprocess      => ((defined? TOOLS_POST_TEST_PREPROCESS)      ? TOOLS_POST_TEST_PREPROCESS      : nil ),
      :pre_mock_generate         => ((defined? TOOLS_PRE_MOCK_GENERATE)         ? TOOLS_PRE_MOCK_GENERATE         : nil ),
      :post_mock_generate        => ((defined? TOOLS_POST_MOCK_GENERATE)        ? TOOLS_POST_MOCK_GENERATE        : nil ),
      :pre_runner_generate       => ((defined? TOOLS_PRE_RUNNER_GENERATE)       ? TOOLS_PRE_RUNNER_GENERATE       : nil ),
      :post_runner_generate      => ((defined? TOOLS_POST_RUNNER_GENERATE)      ? TOOLS_POST_RUNNER_GENERATE      : nil ),
      :pre_compile_execute       => ((defined? TOOLS_PRE_COMPILE_EXECUTE)       ? TOOLS_PRE_COMPILE_EXECUTE       : nil ),
      :post_compile_execute      => ((defined? TOOLS_POST_COMPILE_EXECUTE)      ? TOOLS_POST_COMPILE_EXECUTE      : nil ),
      :pre_link_execute          => ((defined? TOOLS_PRE_LINK_EXECUTE)          ? TOOLS_PRE_LINK_EXECUTE          : nil ),
      :post_link_execute         => ((defined? TOOLS_POST_LINK_EXECUTE)         ? TOOLS_POST_LINK_EXECUTE         : nil ),
      :pre_test_fixture_execute  => ((defined? TOOLS_PRE_TEST_FIXTURE_EXECUTE)  ? TOOLS_PRE_TEST_FIXTURE_EXECUTE  : nil ),
      :post_test_fixture_execute => ((defined? TOOLS_POST_TEST_FIXTURE_EXECUTE) ? TOOLS_POST_TEST_FIXTURE_EXECUTE : nil ),
      :pre_test                  => ((defined? TOOLS_PRE_TEST)                  ? TOOLS_PRE_TEST                  : nil ),
      :post_test                 => ((defined? TOOLS_POST_TEST)                 ? TOOLS_POST_TEST                 : nil ),
      :pre_release               => ((defined? TOOLS_PRE_RELEASE)               ? TOOLS_PRE_RELEASE               : nil ),
      :post_release              => ((defined? TOOLS_POST_RELEASE)              ? TOOLS_POST_RELEASE              : nil ),
      :pre_build                 => ((defined? TOOLS_PRE_BUILD)                 ? TOOLS_PRE_BUILD                 : nil ),
      :post_build                => ((defined? TOOLS_POST_BUILD)                ? TOOLS_POST_BUILD                : nil ),
      :post_error                => ((defined? TOOLS_POST_ERROR)                ? TOOLS_POST_ERROR                : nil ),
    }
  end

  def pre_mock_preprocess(arg_hash);       run_hook( :pre_mock_preprocess,       arg_hash[:header_file] ); end
  def post_mock_preprocess(arg_hash);      run_hook( :post_mock_preprocess,      arg_hash[:header_file] ); end
  def pre_test_preprocess(arg_hash);       run_hook( :pre_test_preprocess,       arg_hash[:test_file]   ); end
  def post_test_preprocess(arg_hash);      run_hook( :post_test_preprocess,      arg_hash[:test_file]   ); end
  def pre_mock_generate(arg_hash);         run_hook( :pre_mock_generate,         arg_hash[:header_file] ); end
  def post_mock_generate(arg_hash);        run_hook( :post_mock_generate,        arg_hash[:header_file] ); end
  def pre_runner_generate(arg_hash);       run_hook( :pre_runner_generate,       arg_hash[:source]      ); end
  def post_runner_generate(arg_hash);      run_hook( :post_runner_generate,      arg_hash[:runner_file] ); end
  def pre_compile_execute(arg_hash);       run_hook( :pre_compile_execute,       arg_hash[:source_file] ); end
  def post_compile_execute(arg_hash);      run_hook( :post_compile_execute,      arg_hash[:object_file] ); end
  def pre_link_execute(arg_hash);          run_hook( :pre_link_execute,          arg_hash[:executable]  ); end
  def post_link_execute(arg_hash);         run_hook( :post_link_execute,         arg_hash[:executable]  ); end
  def pre_test_fixture_execute(arg_hash);  run_hook( :pre_test_fixture_execute,  arg_hash[:executable]  ); end
  def post_test_fixture_execute(arg_hash); run_hook( :post_test_fixture_execute, arg_hash[:executable]  ); end
  def pre_test(test);                      run_hook( :pre_test,                  test                   ); end
  def post_test(test);                     run_hook( :post_test,                 test                   ); end
  def pre_release;                         run_hook( :pre_release                                       ); end
  def post_release;                        run_hook( :post_release                                      ); end
  def pre_build;                           run_hook( :pre_build                                         ); end
  def post_build;                          run_hook( :post_build                                        ); end
  def post_error;                          run_hook( :post_error                                        ); end

  private

  ##
  # Run a hook if its available.
  #
  # :args:
  #   - hook: Name of the hook to run
  #   - name: Name of file (default: "")
  #
  # :return:
  #    shell_result.
  #
  def run_hook_step(hook, name="")
    if (hook[:executable])
      # Handle argument replacemant ({$1}), and get commandline
      cmd = @ceedling[:tool_executor].build_command_line( hook, [], name )
      shell_result = @ceedling[:tool_executor].exec(cmd)
    end
  end

  ##
  # Run a hook if its available.
  #
  # If __which_hook__ is an array, run each of them sequentially.
  #
  # :args:
  #   - which_hook: Name of the hook to run
  #   - name: Name of file
  #
  def run_hook(which_hook, name="")
    if (@config[which_hook])
      @ceedling[:loginator].log("Running command hook #{which_hook}...")
      
      # Single tool config
      if (@config[which_hook].is_a? Hash)
        run_hook_step( @config[which_hook], name )
      
      # Multiple took configs
      elsif (@config[which_hook].is_a? Array)
        @config[which_hook].each do |hook|
          run_hook_step(hook, name)
        end
      
      # Tool config is bad
      else
        msg = "Tool config for command hook #{which_hook} was poorly formed and not run"
        @ceedling[:loginator].log( msg, Verbosity::COMPLAIN )
      end
    end
  end
end

