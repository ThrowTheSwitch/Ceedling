# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Command Hooks plugin with Ceedling's real tool validation and execution. Each hook
# runs a small Ruby script that records the argument the hook hands it as `${1}`.
#
# Each hook receives the argument hash Ceedling's core builds for that build step (see
# the plugin_manager calls in lib/ceedling), so a hook reading the wrong key records an
# empty argument.

require 'spec_helper'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require_relative '../support/integration/configurator_integration_helper'

$LOAD_PATH.unshift( File.expand_path( '../../plugins/command_hooks/lib', __dir__ ) )

require 'command_hooks'

describe 'Command Hooks plugin (integration)' do
  include ConfiguratorIntegrationHelpers

  # Writes each argument it receives to <hook>.txt, one per line
  COMMAND_HOOKS_RECORDER = <<~RUBY
    File.write( "\#{ARGV.shift}.txt", ARGV.join( "\\n" ) )
  RUBY

  def recording_hook(name)
    return { executable: 'ruby', arguments: ['record.rb', name.to_s, '"${1}"'] }
  end

  def plugin_for(config)
    objects = configurator_objects( quiet_loginator )
    objects[:setupinator]     = double( 'setupinator', config_hash: config )
    objects[:config_walkinator] ||= ConfigWalkinator.new
    return CommandHooks.new( objects, 'command_hooks', '/plugins/command_hooks' )
  end

  def in_project
    Dir.mktmpdir( 'command_hooks' ) do |root|
      Dir.chdir( root ) do
        File.write( 'record.rb', COMMAND_HOOKS_RECORDER )
        yield
      end
    end
  end

  def recorded(hook)
    return File.exist?( "#{hook}.txt" ) ? File.read( "#{hook}.txt" ) : nil
  end

  # Each hook, the argument hash or values the core passes it, and the `${1}` it promises
  COMMAND_HOOKS_CORE_CALLS = {
    pre_mock_preprocess:       [{ header_file: 'src/adc.h', test: 'test_adc' },                    'src/adc.h'],
    post_mock_preprocess:      [{ header_file: 'src/adc.h', test: 'test_adc' },                    'src/adc.h'],
    pre_test_preprocess:       [{ test_file: 'test/test_adc.c', test: 'test_adc' },                'test/test_adc.c'],
    post_test_preprocess:      [{ test_file: 'test/test_adc.c', test: 'test_adc' },                'test/test_adc.c'],
    pre_mock_generate:         [{ header_file: 'src/adc.h', context: :test, output_path: 'mocks' }, 'src/adc.h'],
    post_mock_generate:        [{ header_file: 'src/adc.h', context: :test, output_path: 'mocks' }, 'src/adc.h'],
    pre_runner_generate:       [{ context: :test, test_file: 'test/test_adc.c', input_file: 'test/test_adc.c', runner_file: 'runners/test_adc_runner.c' }, 'test/test_adc.c'],
    post_runner_generate:      [{ context: :test, test_file: 'test/test_adc.c', input_file: 'test/test_adc.c', runner_file: 'runners/test_adc_runner.c' }, 'runners/test_adc_runner.c'],
    pre_compile_execute:       [{ context: :test, source: 'src/adc.c', object: 'out/adc.o' },     'src/adc.c'],
    post_compile_execute:      [{ context: :test, source: 'src/adc.c', object: 'out/adc.o' },     'src/adc.c'],
    pre_link_execute:          [{ context: :test, executable: 'out/test_adc.out' },               'out/test_adc.out'],
    post_link_execute:         [{ context: :test, executable: 'out/test_adc.out' },               'out/test_adc.out'],
    pre_test_fixture_execute:  [{ context: :test, executable: 'out/test_adc.out' },               'out/test_adc.out'],
    post_test_fixture_execute: [{ context: :test, executable: 'out/test_adc.out' },               'out/test_adc.out']
  }.freeze

  describe 'hooks with an argument hash' do
    COMMAND_HOOKS_CORE_CALLS.each do |hook, (arg_hash, expected)|
      it "runs :#{hook} with #{expected} as ${1}" do
        in_project do
          plugin_for( command_hooks: { hook => recording_hook( hook ) } ).public_send( hook, arg_hash )

          expect(recorded( hook )).to eq( expected )
        end
      end
    end
  end

  describe 'hooks with plain values' do
    it 'runs :pre_test and :post_test with the test filepath' do
      in_project do
        plugin = plugin_for( command_hooks: { pre_test: recording_hook( :pre_test ), post_test: recording_hook( :post_test ) } )
        plugin.pre_test( 'test/test_adc.c' )
        plugin.post_test( 'test/test_adc.c' )

        expect([recorded( :pre_test ), recorded( :post_test )]).to all( eq( 'test/test_adc.c' ) )
      end
    end

    it 'runs :pre_test_build with the build context' do
      in_project do
        plugin_for( command_hooks: { pre_test_build: recording_hook( :pre_test_build ) } ).pre_test_build( :gcov, 12.5 )

        expect(recorded( :pre_test_build )).to eq( 'gcov' )
      end
    end

    it 'runs :pre_build, :post_build, and :post_error with the timestamp' do
      in_project do
        hooks  = %i[pre_build post_build post_error]
        plugin = plugin_for( command_hooks: hooks.to_h { |hook| [hook, recording_hook( hook )] } )
        hooks.each { |hook| plugin.public_send( hook, 3.25 ) }

        expect(hooks.map { |hook| recorded( hook ) }).to all( eq( '3.25' ) )
      end
    end
  end

  describe 'configuration' do
    it 'runs each tool of a hook given a list, in order' do
      in_project do
        first  = { executable: 'ruby', arguments: ['-e', '"File.write(%q{order.txt}, %q{a})"'] }
        second = { executable: 'ruby', arguments: ['-e', '"File.write(%q{order.txt}, File.read(%q{order.txt}) + %q{b})"'] }
        plugin_for( command_hooks: { pre_build: [first, second] } ).pre_build( 1 )

        expect(File.read( 'order.txt' )).to eq( 'ab' )
      end
    end

    it 'refuses an unrecognized hook' do
      expect { plugin_for( command_hooks: { pre_bulid: recording_hook( :pre_bulid ) } ) }
        .to raise_error( CeedlingException, /Unrecognized hooks/ )
    end

    it 'refuses a missing :command_hooks section' do
      expect { plugin_for( {} ) }.to raise_error( CeedlingException, /missing a required configuration block/ )
    end

    it 'refuses a hook whose executable does not exist' do
      expect { plugin_for( command_hooks: { pre_build: { executable: 'no-such-hook-tool' } } ) }
        .to raise_error( CeedlingException, /no-such-hook-tool/ )
    end

    it 'leaves the project configuration without a :logging entry of its own' do
      config = { command_hooks: { pre_build: recording_hook( :pre_build ) } }

      in_project { plugin_for( config ) }

      expect(config).not_to have_key( :logging )
    end
  end

end
