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
    # Get a copy of the project configuration
    project_config = @ceedling[:setupinator].config_hash

    # Convenience object references
    @loginator = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
    @walkinator = @ceedling[:config_walkinator]
    @tool_validator = @ceedling[:tool_validator]
    @tool_executor = @ceedling[:tool_executor]
    @verbosinator = @ceedling[:verbosinator]
    @configurator_validator = @ceedling[:configurator_validator]
    
    # Look up if the accompanying `:command_hooks` configuration block exists
    config_exists = @configurator_validator.exists?(
      project_config,
      COMMAND_HOOKS_SYM
    )

    # Go boom if the required configuration block does not exist
    unless config_exists
      name = @reportinator.generate_config_walk([COMMAND_HOOKS_SYM])
      error = "Command Hooks plugin is enabled but is missing a required configuration block `#{name}`"
      raise CeedlingException.new(error)
    end
    
    @config = project_config[COMMAND_HOOKS_SYM]
    
    # Validate the command hook keys (look out for typos)
    validate_config( @config )
    
    # Validate the tools beneath the keys
    @config.each do |hook, tool|
      if tool.is_a?(Array)
        tool.each_index {|index| validate_hook( project_config, hook, index )}
      else
        validate_hook( project_config, hook )
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

  ### Private

  private
  
  ##
  # Validate plugin configuration.
  #
  # :args:
  #   - config: :command_hooks section from project config hash
  #
  def validate_config(config)
    unless config.is_a?(Hash)
      name = @reportinator.generate_config_walk([COMMAND_HOOKS_SYM])
      error = "Expected configuration #{name} to be a Hash but found #{config.class}"
      raise CeedlingException.new(error)
    end
    
    unrecognized_hooks = config.keys - COMMAND_HOOKS_LIST
    
    unrecognized_hooks.each do |not_a_hook|
      name = @reportinator.generate_config_walk( [COMMAND_HOOKS_SYM, not_a_hook] )
      error = "Unrecognized Command Hook: #{name}"
      @loginator.log( error, Verbosity::ERRORS )
    end
    
    unless unrecognized_hooks.empty?
      error = "Unrecognized hooks found in Command Hooks plugin configuration"
      raise CeedlingException.new(error)
    end
  end
  
  ##
  # Validate given hook
  #
  # :args:
  #   - config: Project configuration hash
  #   - keys: Key and index of hook inside :command_hooks configuration
  #
  def validate_hook(config, *keys)
    walk = [COMMAND_HOOKS_SYM, *keys]
    name = @reportinator.generate_config_walk( walk )
    entry, _ = @walkinator.fetch_value( *walk, hash:config )

    if entry.nil?
      raise CeedlingException.new( "Missing Command Hook plugin configuration for #{name}" )
    end
        
    unless entry.is_a?(Hash)
      error = "Expected configuration #{name} for Command Hooks plugin to be a Hash but found #{entry.class}"
      raise CeedlingException.new( error )
    end

    # Validate the Ceedling tool components of the hook entry config
    @tool_validator.validate( tool: entry, name: name, boom: true )

    # Default logging configuration
    config[:logging] = false if config[:logging].nil?
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
      msg = "Running Command Hook :#{which_hook}"
      msg = @reportinator.generate_progress( msg )
      @loginator.log( msg )
      
      # Single tool config
      if (@config[which_hook].is_a? Hash)
        run_hook_step( which_hook, @config[which_hook], name )
      
      # Multiple tool configs
      elsif (@config[which_hook].is_a? Array)
        @config[which_hook].each do |hook|
          run_hook_step( which_hook, hook, name )
        end
      
      # Tool config is bad
      else
        msg = "The tool config for Command Hook #{which_hook} was poorly formed and not run"
        @loginator.log( msg, Verbosity::COMPLAIN )
      end
    end
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
  def run_hook_step(which_hook, hook, name="")
    if (hook[:executable])
      # Handle argument replacemant ({$1}), and get commandline
      cmd = @ceedling[:tool_executor].build_command_line( hook, [], name )
      shell_result = @ceedling[:tool_executor].exec( cmd )

      # If hook logging is enabled
      if hook[:logging]
        # Skip debug logging -- allow normal tool debug logging to do its thing
        return if @verbosinator.should_output?( Verbosity::DEBUG )

        output = shell_result[:output].strip

        # Set empty output to empty string if we're in OBNOXIOUS logging mode
        output = '<empty>' if output.empty? and @verbosinator.should_output?( Verbosity::OBNOXIOUS )

        # Don't add to logging output if there's nothing to output
        return if output.empty?

        # NORMAL and OBNOXIOUS logging
        @loginator.log( "Command Hook :#{which_hook} output >> #{output}" )
      end
    end
  end

end
