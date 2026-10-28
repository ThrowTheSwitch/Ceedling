# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'rake'

# bin/versionator.rb (pulled in transitively by cli_helper.rb) uses bare `require`
# statements (`require 'exceptions'`, `require 'constants'`, `require 'version'`)
# that only resolve when lib/ceedling/ and lib/ are directly on the load path --
# true in the real bin/ceedling bootstrap (which adds lib/ceedling/ via
# CEEDLING_APPCFG[:ceedling_lib_path]) but not in this spec harness's load path
# setup. Add the same directories here so `require 'cli_helper'` succeeds.
here = File.dirname(__FILE__)
$: << File.join(here, '../../../lib/ceedling')
$: << File.join(here, '../../../lib')

require 'cli_helper'
require 'app_cfg'
require 'ceedling/ruby_expandinator'
# CliHelper#test_task? references RakeTaskRegistry::TAG_TEST, but only
# bin/cli_handler.rb requires this file in the real bootstrap (loaded before
# cli_helper.rb's methods are ever called) -- required directly here since this
# spec exercises CliHelper in isolation.
require 'ceedling/rake_app/rake_task_registry'

describe CliHelper do
  before(:each) do
    @ruby_expandinator  = RubyExpandinator.new
    @rake_task_registry = double('rake_task_registry').as_null_object
    @file_wrapper       = double('file_wrapper').as_null_object
    @config_walkinator  = double('config_walkinator').as_null_object
    @path_validator     = double('path_validator').as_null_object
    @loginator          = double('loginator').as_null_object

    @cli_helper = described_class.new({
      :file_wrapper       => @file_wrapper,
      :actionator         => double('actionator').as_null_object,
      :config_walkinator  => @config_walkinator,
      :path_validator     => @path_validator,
      :rake_task_registry => @rake_task_registry,
      :loginator          => @loginator,
      :reportinator       => double('reportinator').as_null_object,
      :system_wrapper     => double('system_wrapper').as_null_object,
      :ruby_expandinator  => @ruby_expandinator,
    })
  end

  describe '#set_ruby_replacement' do
    it 'enables the feature when passed true' do
      @cli_helper.set_ruby_replacement( true )

      expect(@ruby_expandinator.enabled?).to eq(true)
    end

    it 'leaves the feature disabled when passed false' do
      @cli_helper.set_ruby_replacement( false )

      expect(@ruby_expandinator.enabled?).to eq(false)
    end

    it 'leaves the feature disabled when passed nil' do
      @cli_helper.set_ruby_replacement( nil )

      expect(@ruby_expandinator.enabled?).to eq(false)
    end

    it 'never disables an already-enabled feature' do
      @cli_helper.set_ruby_replacement( true )
      @cli_helper.set_ruby_replacement( false )

      expect(@ruby_expandinator.enabled?).to eq(true)
    end
  end

  describe '#process_force_test_rerun' do
    it 'does nothing when the flag is false, without even consulting the task registry' do
      expect(@rake_task_registry).to_not receive(:task_is?)

      expect {
        @cli_helper.process_force_test_rerun( force_test_rerun: false, tasks: [], default_tasks: [] )
      }.to_not raise_error
    end

    it 'raises when the flag is true and no test task is present in tasks or default_tasks' do
      allow(@rake_task_registry).to receive(:task_is?).and_return( false )

      expect {
        @cli_helper.process_force_test_rerun( force_test_rerun: true, tasks: ['release'], default_tasks: ['test:all'] )
      }.to raise_error( CeedlingException, /only applicable to test tasks/ )
    end

    it 'does not raise when the flag is true and a test task is present in tasks' do
      allow(@rake_task_registry).to receive(:task_is?).with( 'test:all', RakeTaskRegistry::TAG_TEST ).and_return( true )

      expect {
        @cli_helper.process_force_test_rerun( force_test_rerun: true, tasks: ['test:all'], default_tasks: [] )
      }.to_not raise_error
    end

    it 'does not raise when the flag is true, tasks is empty, and a test task is present in default_tasks' do
      allow(@rake_task_registry).to receive(:task_is?).with( 'test:all', RakeTaskRegistry::TAG_TEST ).and_return( true )

      expect {
        @cli_helper.process_force_test_rerun( force_test_rerun: true, tasks: [], default_tasks: ['test:all'] )
      }.to_not raise_error
    end
  end

  # Whether a command's tasks build a release decides what build/vendor needs (GH #1361)
  describe '#release_task?' do
    it 'is true when any task belongs to a release-building namespace' do
      allow(@rake_task_registry).to receive(:task_is?) { |task, tag| task == 'release' && tag == RakeTaskRegistry::TAG_RELEASE }

      expect( @cli_helper.release_task?( tasks: ['test:all', 'release'] ) ).to be(true)
      expect( @cli_helper.release_task?( tasks: ['test:all', 'files:test'] ) ).to be(false)
    end
  end

  describe '#docs_bundle?' do
    it 'is true when the installation holds an HTML documentation bundle' do
      allow(@file_wrapper).to receive(:directory?).with( File.join( '/ceedling', DOCS_SITE_LOCAL_PATH ) ).and_return( true )

      expect(@cli_helper.docs_bundle?( '/ceedling' )).to be( true )
    end

    it 'is false when it does not, as for any --local copy' do
      allow(@file_wrapper).to receive(:directory?).with( File.join( '/ceedling', DOCS_SITE_LOCAL_PATH ) ).and_return( false )

      expect(@cli_helper.docs_bundle?( '/ceedling' )).to be( false )
    end
  end

  describe '#set_verbosity' do
    after(:each) do
      # These globals are frozen once set -- clear them so later specs in the
      # same process (unit suite runs as one process) start from a clean slate.
      Object.send(:remove_const, 'PROJECT_VERBOSITY') if Object.const_defined?('PROJECT_VERBOSITY')
      Object.send(:remove_const, 'PROJECT_DEBUG') if Object.const_defined?('PROJECT_DEBUG')
    end

    it 'defaults to Verbosity::NORMAL when given nil' do
      expect(@cli_helper.set_verbosity( nil )).to eq( Verbosity::NORMAL )
      expect(PROJECT_VERBOSITY).to eq( Verbosity::NORMAL )
      expect(PROJECT_DEBUG).to eq( false )
    end

    it 'passes an Integer verbosity constant through directly' do
      expect(@cli_helper.set_verbosity( Verbosity::OBNOXIOUS )).to eq( Verbosity::OBNOXIOUS )
    end

    it 'parses a numeric string as an integer verbosity level' do
      expect(@cli_helper.set_verbosity( '4' )).to eq( 4 )
    end

    it 'looks up a named verbosity string' do
      expect(@cli_helper.set_verbosity( 'debug' )).to eq( Verbosity::DEBUG )
      expect(PROJECT_DEBUG).to eq( true )
    end

    it 'raises for an unrecognized named verbosity' do
      expect { @cli_helper.set_verbosity( 'not-a-real-level' ) }.to raise_error( /Unkown Verbosity/ )
    end

    it 'is idempotent once established unless override is true' do
      @cli_helper.set_verbosity( Verbosity::DEBUG )

      expect(@cli_helper.set_verbosity( Verbosity::NORMAL, override: false )).to eq( Verbosity::DEBUG )
    end

    it 'reconfigures when override is true, the default' do
      @cli_helper.set_verbosity( Verbosity::DEBUG )

      expect(@cli_helper.set_verbosity( Verbosity::NORMAL )).to eq( Verbosity::NORMAL )
    end
  end

  describe '#process_log_filepath' do
    around(:each) do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it 'returns an empty string when logging is explicitly disabled' do
      result = @cli_helper.process_log_filepath( @tmpdir, false, 'ignored.log' )

      expect(result).to eq( '' )
    end

    it 'returns an empty string when neither --log nor --logfile is set' do
      result = @cli_helper.process_log_filepath( @tmpdir, nil, '' )

      expect(result).to eq( '' )
    end

    it 'uses the explicit --logfile path when one is given, creating its directory' do
      logfile = File.join( @tmpdir, 'nested', 'custom.log' )
      expect(@file_wrapper).to receive(:mkdir).with( File.join( @tmpdir, 'nested' ) )

      result = @cli_helper.process_log_filepath( @tmpdir, nil, logfile )

      expect(result).to eq( File.expand_path( logfile ) )
    end

    it 'falls back to the default logfile path under logging_path when --log is enabled with no --logfile' do
      # @tmpdir itself already exists, so no mkdir call is expected here.
      expect(@file_wrapper).to_not receive(:mkdir)

      result = @cli_helper.process_log_filepath( @tmpdir, true, '' )

      expect(result).to eq( File.expand_path( File.join( @tmpdir, DEFAULT_CEEDLING_LOGFILE ) ) )
    end
  end

  describe '#run_rake_tasks' do
    before(:each) do
      @rake_application = double('rake_application')
      allow(Rake).to receive(:application).and_return( @rake_application )
    end

    it 'raises a friendlier CeedlingException when Rake reports an unrecognized task' do
      allow(@rake_application).to receive(:collect_command_line_tasks).with( ['bogus:task'] )
      allow(@rake_application).to receive(:top_level).and_raise(
        RuntimeError.new("Don't know how to build task 'bogus:task' (See the list of available tasks with `rake --tasks`)")
      )

      expect {
        @cli_helper.run_rake_tasks( ['bogus:task'] )
      }.to raise_error( CeedlingException, /Unrecognized build task 'bogus:task'/ )
    end

    it 're-raises RuntimeErrors unrelated to an unrecognized task unchanged' do
      allow(@rake_application).to receive(:collect_command_line_tasks)
      allow(@rake_application).to receive(:top_level).and_raise( RuntimeError.new('Something else entirely went wrong') )

      expect {
        @cli_helper.run_rake_tasks( ['test:all'] )
      }.to raise_error( RuntimeError, 'Something else entirely went wrong' )
    end

    it 'does not raise when Rake completes normally' do
      allow(@rake_application).to receive(:collect_command_line_tasks)
      allow(@rake_application).to receive(:top_level)

      expect { @cli_helper.run_rake_tasks( ['test:all'] ) }.to_not raise_error
    end
  end
end
