# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/config/config_walkinator'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/command_hooks/lib', __dir__ ) )

require 'command_hooks'

# Hook validation and dispatch. Tools are doubled: each command records the tool name and
# the arguments a hook gave it, and nothing runs.
describe CommandHooks do

  let(:commands) { [] }
  let(:logged)   { [] }
  let(:verbose)  { false }

  let(:tool_executor) do
    double( 'tool_executor' ).tap do |executor|
      allow(executor).to receive(:build_command_line) { |tool, _extra, *args| { name: tool[:name], args: args } }
      allow(executor).to receive(:exec) { |command| commands << command; { output: "out of #{command[:name]}\n" } }
    end
  end

  def plugin_for(config)
    objects = {
      setupinator:            double( 'setupinator', config_hash: config ),
      loginator:              double( 'loginator' ).tap { |log| allow(log).to receive(:log) { |message, *| logged << message } },
      reportinator:           double( 'reportinator', generate_progress: 'progress' ).tap { |r| allow(r).to receive(:generate_config_walk) { |keys| keys.map { |k| ":#{k}" }.join( ' ↳ ' ) } },
      config_walkinator:      ConfigWalkinator.new,
      configurator_validator: double( 'configurator_validator' ).tap { |v| allow(v).to receive(:exists?) { |cfg, key| !cfg[key].nil? } },
      tool_validator:         double( 'tool_validator', validate: true ),
      tool_executor:          tool_executor,
      verbosinator:           double( 'verbosinator' ).tap { |v| allow(v).to receive(:should_output?) { verbose } }
    }
    return described_class.new( objects, 'command_hooks', '/plugins/command_hooks' )
  end

  def tool(name)
    return { executable: name, name: name }
  end

  describe 'arguments' do
    # Each hook's argument hash, as the core builds it, and the arguments its tools receive
    {
      pre_mock_preprocess:       [{ header_file: 'adc.h' },                          ['adc.h']],
      post_mock_preprocess:      [{ header_file: 'adc.h' },                          ['adc.h']],
      pre_test_preprocess:       [{ test_file: 'test_adc.c' },                       ['test_adc.c']],
      post_test_preprocess:      [{ test_file: 'test_adc.c' },                       ['test_adc.c']],
      pre_mock_generate:         [{ header_file: 'adc.h' },                          ['adc.h']],
      post_mock_generate:        [{ header_file: 'adc.h' },                          ['adc.h']],
      pre_runner_generate:       [{ test_file: 'test_adc.c', runner_file: 'r.c' },   ['test_adc.c']],
      post_runner_generate:      [{ test_file: 'test_adc.c', runner_file: 'r.c' },   ['r.c']],
      pre_compile_execute:       [{ source: 'adc.c', object: 'adc.o' },              ['adc.c', 'adc.o']],
      post_compile_execute:      [{ source: 'adc.c', object: 'adc.o' },              ['adc.c', 'adc.o']],
      pre_link_execute:          [{ executable: 'test_adc.out' },                    ['test_adc.out']],
      post_link_execute:         [{ executable: 'test_adc.out' },                    ['test_adc.out']],
      pre_test_fixture_execute:  [{ executable: 'test_adc.out' },                    ['test_adc.out']],
      post_test_fixture_execute: [{ executable: 'test_adc.out' },                    ['test_adc.out']]
    }.each do |hook, (arg_hash, args)|
      it "hands :#{hook} tools #{args.join( ' and ' )}" do
        plugin_for( command_hooks: { hook => tool( 'hook' ) } ).public_send( hook, arg_hash )

        expect(commands).to eq( [{ name: 'hook', args: args }] )
      end
    end

    it 'hands test hooks the test filepath and build hooks their context and timestamp' do
      plugin = plugin_for( command_hooks: { pre_test: tool( 't' ), pre_test_build: tool( 'b' ), post_build: tool( 'p' ) } )
      plugin.pre_test( 'test_adc.c' )
      plugin.pre_test_build( :gcov, 1.5 )
      plugin.post_build( 2.5 )

      expect(commands.map { |c| c[:args] }).to eq( [['test_adc.c'], ['gcov', '1.5'], ['2.5']] )
    end

    # On Windows, Ceedling's stopwatch is the wall clock, a Time rather than a Float
    it 'hands build hooks their stopwatch value in seconds whether it arrives as a Float or a Time' do
      plugin = plugin_for( command_hooks: { pre_build: tool( 'a' ), post_build: tool( 'b' ), pre_release_build: tool( 'c' ), post_test_build: tool( 'd' ) } )
      plugin.pre_build( Time.at( 1_700_000_000, 250, :millisecond ) )
      plugin.post_build( 12.5 )
      plugin.pre_release_build( Time.at( 1_700_000_001, 500, :millisecond ) )
      plugin.post_test_build( :test, Time.at( 1_700_000_002, 750, :millisecond ) )

      expect(commands.map { |c| c[:args] }).to eq( [['1700000000.25'], ['12.5'], ['1700000001.5'], ['test', '1700000002.75']] )
    end

    it 'runs nothing for a hook without configured tools' do
      plugin_for( command_hooks: {} ).pre_build( 1 )

      expect(commands).to be_empty
    end
  end

  describe 'tool lists' do
    it 'runs each tool of a hook given a list, in order' do
      plugin_for( command_hooks: { pre_build: [tool( 'first' ), tool( 'second' )] } ).pre_build( 1 )

      expect(commands.map { |c| c[:name] }).to eq( ['first', 'second'] )
    end

    it 'refuses a list entry that is not a tool' do
      expect { plugin_for( command_hooks: { pre_build: [tool( 'first' ), 'second'] } ) }
        .to raise_error( CeedlingException, /:pre_build ↳ :1.*Hash/ )
    end
  end

  describe 'validation' do
    it 'refuses a missing :command_hooks section' do
      expect { plugin_for( {} ) }.to raise_error( CeedlingException, /missing a required configuration block/ )
    end

    it 'refuses an unrecognized hook, naming it' do
      expect { plugin_for( command_hooks: { pre_bulid: tool( 'x' ) } ) }.to raise_error( CeedlingException, /Unrecognized hooks/ )
      expect(logged.join).to include( ':pre_bulid' )
    end

    it 'names each hook tool after its hook when it has no name' do
      config = { command_hooks: { pre_build: { executable: 'x' }, post_build: [{ executable: 'y' }] } }
      plugin_for( config )

      expect(config[:command_hooks][:pre_build][:name]).to eq( 'pre_build' )
      expect(config[:command_hooks][:post_build][0][:name]).to eq( 'post_build_0' )
    end

    it 'turns hook logging off by default, on the hook rather than the project configuration' do
      config = { command_hooks: { pre_build: tool( 'x' ) } }
      plugin_for( config )

      expect(config[:command_hooks][:pre_build][:logging]).to be( false )
      expect(config).not_to have_key( :logging )
    end
  end

  describe 'logging' do
    it 'logs a logging hook tool output' do
      plugin_for( command_hooks: { pre_build: tool( 'x' ).merge( logging: true ) } ).pre_build( 1 )

      expect(logged).to include( 'Command Hook :pre_build output >> out of x' )
    end

    it 'leaves output unlogged for a hook without logging' do
      plugin_for( command_hooks: { pre_build: tool( 'x' ) } ).pre_build( 1 )

      expect(logged.join).not_to include( 'out of x' )
    end
  end

end
