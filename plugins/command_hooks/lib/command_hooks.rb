# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugin'

COMMAND_HOOKS_ROOT_NAME = 'command_hooks'.freeze
COMMAND_HOOKS_SYM       = COMMAND_HOOKS_ROOT_NAME.to_sym

COMMAND_HOOKS_LIST = [
  :pre_mock_preprocess,
  :post_mock_preprocess,
  :pre_test_preprocess,
  :post_test_preprocess,
  :pre_mock_generate,
  :post_mock_generate,
  :pre_runner_generate,
  :post_runner_generate,
  :pre_compile_execute,
  :post_compile_execute,
  :pre_link_execute,
  :post_link_execute,
  :pre_test_fixture_execute,
  :post_test_fixture_execute,
  :pre_test,
  :post_test,
  :pre_release,
  :post_release,
  :pre_build,
  :post_build,
  :post_error,
].freeze

class CommandHooks < Plugin

  def setup
    project_config = @ceedling[:setupinator].config_hash
    
    config_exists = @ceedling[:configurator_validator].exists?(
      project_config,
      COMMAND_HOOKS_SYM
    )
    
    unless config_exists
      raise CeedlingException.new("Missing configuration :command_hooks")
    end
    
    @config = project_config[COMMAND_HOOKS_SYM]
    
    validate_config(@config)
    
    @config.each do |hook, tool|
      if tool.is_a?(Array)
        tool.each_index {|index| validate_hook_tool(project_config, hook, index)}
      else
        validate_hook_tool(project_config, hook)
      end
    end
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
  # Validate plugin configuration.
  #
  # :args:
  #   - config: :command_hooks section from project config hash
  #
  def validate_config(config)
    unless config.is_a?(Hash)
      error = "Expected configuration :command_hooks to be a Hash but found #{config.class}"
      raise CeedlingException.new(error)
    end
    
    unknown_hooks = config.keys - COMMAND_HOOKS_LIST
    
    unknown_hooks.each do |not_a_hook|
      error = "Unrecognized hook '#{not_a_hook}'."
      @ceedling[:loginator].log(error, Verbosity::ERRORS)
    end
    
    unless unknown_hooks.empty?
      error = "Unrecognized hooks have been found in project configuration"
      raise CeedlingException.new(error)
    end
  end
  
  ##
  # Validate given hook tool.
  #
  # :args:
  #   - config: Project configuration hash
  #   - keys: Key and index of hook inside :command_hooks configuration
  #
  def validate_hook_tool(config, *keys)
    walk = [COMMAND_HOOKS_SYM, *keys]
    name = @ceedling[:reportinator].generate_config_walk(walk)
    hash = @ceedling[:config_walkinator].fetch_value(config, *walk)
    
    tool_exists = @ceedling[:configurator_validator].exists?(config, *walk)
    
    unless tool_exists
      raise CeedlingException.new("Missing configuration #{name}")
    end
    
    tool = hash[:value]
    
    unless tool.is_a?(Hash)
      error = "Expected configuration #{name} to be a Hash but found #{tool.class}"
      raise CeedlingException.new(error)
    end
  
    @ceedling[:tool_validator].validate(tool: tool, name: name, boom: true)
  end
  
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
