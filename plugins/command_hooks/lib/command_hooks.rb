# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/tool_executor'

COMMAND_HOOKS_ROOT_NAME = 'command_hooks'.freeze
COMMAND_HOOKS_SYM       = COMMAND_HOOKS_ROOT_NAME.to_sym

# Hooks whose build step hands over an argument hash, and the hash entries its tools
# receive as ${1}, ${2}, ... The keys are those Ceedling's core builds for each step.
COMMAND_HOOKS_ARGUMENTS = {
  pre_mock_preprocess:       [:header_file],
  post_mock_preprocess:      [:header_file],
  pre_test_preprocess:       [:test_file],
  post_test_preprocess:      [:test_file],
  pre_mock_generate:         [:header_file],
  post_mock_generate:        [:header_file],
  pre_runner_generate:       [:test_file],
  post_runner_generate:      [:runner_file],
  pre_compile_execute:       [:source, :object],
  post_compile_execute:      [:source, :object],
  pre_link_execute:          [:executable],
  post_link_execute:         [:executable],
  pre_test_fixture_execute:  [:executable],
  post_test_fixture_execute: [:executable]
}.freeze

# Hooks whose build step hands over plain values, which their tools receive in order
COMMAND_HOOKS_VALUES = %i[pre_test post_test pre_test_build post_test_build pre_release_build post_release_build
                          pre_build post_build post_error].freeze

COMMAND_HOOKS_LIST = (COMMAND_HOOKS_ARGUMENTS.keys + COMMAND_HOOKS_VALUES).freeze

# Runs the tools a project configures under :command_hooks at Ceedling's build steps.
#
# Each hook takes one tool or a list of tools, every one validated as Ceedling validates
# any tool. A tool receives its hook's arguments as ${1}, ${2}, and so on, and logs its
# output when its :logging is set.
class CommandHooks < Plugin

  def setup
    project_config = @ceedling[:setupinator].config_hash

    @loginator     = @ceedling[:loginator]
    @reportinator  = @ceedling[:reportinator]
    @verbosinator  = @ceedling[:verbosinator]

    unless @ceedling[:configurator_validator].exists?( project_config, COMMAND_HOOKS_SYM )
      name = @reportinator.generate_config_walk( [COMMAND_HOOKS_SYM] )
      raise CeedlingException.new( "Command Hooks plugin is enabled but is missing a required configuration block `#{name}`" )
    end

    config = project_config[COMMAND_HOOKS_SYM]
    validate_config( config )

    # Every hook as a list of its validated tools
    @hooks = config.to_h { |hook, tools| [hook, validate_tools( hook, tools )] }
  end

  COMMAND_HOOKS_ARGUMENTS.each do |hook, keys|
    define_method( hook ) { |arg_hash| run_hook( hook, *arg_hash.values_at( *keys ) ) }
  end

  def pre_test(test);                        run_hook( :pre_test,           test ); end
  def post_test(test);                       run_hook( :post_test,          test ); end
  def pre_test_build(context, timestamp_s);  run_hook( :pre_test_build,     context.to_s, seconds( timestamp_s ) ); end
  def post_test_build(context, timestamp_s); run_hook( :post_test_build,    context.to_s, seconds( timestamp_s ) ); end
  def pre_release_build(timestamp_s);        run_hook( :pre_release_build,  seconds( timestamp_s ) ); end
  def post_release_build(timestamp_s);       run_hook( :post_release_build, seconds( timestamp_s ) ); end
  def pre_build(timestamp_s);                run_hook( :pre_build,          seconds( timestamp_s ) ); end
  def post_build(timestamp_s);               run_hook( :post_build,         seconds( timestamp_s ) ); end
  def post_error(timestamp_s);               run_hook( :post_error,         seconds( timestamp_s ) ); end

  ### Private

  private

  # A stopwatch value as seconds. Ceedling's stopwatch is a Float count of seconds on most
  # platforms but the wall clock, a Time, on Windows. Converting through the exact
  # Rational keeps a Time's fraction from picking up rounding noise.
  def seconds(timestamp)
    return timestamp.to_r.to_f.to_s
  end

  # The :command_hooks section must be a hash of recognized hooks, so a misspelled hook
  # stops the build rather than silently never running
  def validate_config(config)
    unless config.is_a?( Hash )
      name = @reportinator.generate_config_walk( [COMMAND_HOOKS_SYM] )
      raise CeedlingException.new( "Expected configuration #{name} to be a Hash but found #{config.class}" )
    end

    unrecognized = config.keys - COMMAND_HOOKS_LIST
    return if unrecognized.empty?

    unrecognized.each do |hook|
      @loginator.log( "Unrecognized Command Hook: #{@reportinator.generate_config_walk( [COMMAND_HOOKS_SYM, hook] )}", Verbosity::ERRORS )
    end
    raise CeedlingException.new( 'Unrecognized hooks found in Command Hooks plugin configuration' )
  end

  # A hook's tools as a list, each validated. A single tool may stand alone or be the only
  # entry in a list.
  def validate_tools(hook, tools)
    return [validate_tool( tools, [hook] )] unless tools.is_a?( Array )

    return tools.each_with_index.map { |tool, index| validate_tool( tool, [hook, index] ) }
  end

  def validate_tool(tool, keys)
    name = @reportinator.generate_config_walk( [COMMAND_HOOKS_SYM, *keys] )

    raise CeedlingException.new( "Missing Command Hook plugin configuration for #{name}" ) if tool.nil?
    unless tool.is_a?( Hash )
      raise CeedlingException.new( "Expected configuration #{name} for Command Hooks plugin to be a Hash but found #{tool.class}" )
    end

    ToolExecutor.default_name!( tool, keys.join( '_' ) )
    @ceedling[:tool_validator].validate( tool: tool, name: name, boom: true )
    tool[:logging] = false if tool[:logging].nil?

    return tool
  end

  # Runs each of a hook's tools in order, handing each the hook's arguments
  def run_hook(hook, *args)
    tools = @hooks[hook]
    return if tools.nil?

    @loginator.log( @reportinator.generate_progress( "Running Command Hook :#{hook}" ) )
    tools.each { |tool| run_tool( hook, tool, *args ) }
  end

  def run_tool(hook, tool, *args)
    command      = @ceedling[:tool_executor].build_command_line( tool, [], *args )
    shell_result = @ceedling[:tool_executor].exec( command )
    log_output( hook, shell_result[:output] ) if tool[:logging]
  end

  # Debug verbosity already logs every tool's output, so a hook's own logging stands aside
  def log_output(hook, output)
    return if @verbosinator.should_output?( Verbosity::DEBUG )

    output = output.to_s.strip
    output = '<empty>' if output.empty? and @verbosinator.should_output?( Verbosity::OBNOXIOUS )
    return if output.empty?

    @loginator.log( "Command Hook :#{hook} output >> #{output}" )
  end

end
