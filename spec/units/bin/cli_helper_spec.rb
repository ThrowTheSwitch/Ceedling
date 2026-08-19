# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

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
require 'ceedling/ruby_expandinator'
# CliHelper#test_task? references RakeTaskRegistry::TAG_TEST, but only
# bin/cli_handler.rb requires this file in the real bootstrap (loaded before
# cli_helper.rb's methods are ever called) -- required directly here since this
# spec exercises CliHelper in isolation.
require 'ceedling/rake_app/rake_task_registry'

# Scoped narrowly to #set_ruby_replacement and #process_force_test_rerun, the
# --ruby-replacement and --force-test-rerun CLI flags' wiring. Broader CliHelper
# coverage (including the pre-existing #process_testcase_filters and
# #process_graceful_fail this new method is modeled on) is a pre-existing gap
# outside either feature's scope.
describe CliHelper do
  before(:each) do
    @ruby_expandinator  = RubyExpandinator.new
    @rake_task_registry = double('rake_task_registry').as_null_object

    @cli_helper = described_class.new({
      :file_wrapper       => double('file_wrapper').as_null_object,
      :actions_wrapper    => double('actions_wrapper').as_null_object,
      :config_walkinator  => double('config_walkinator').as_null_object,
      :path_validator     => double('path_validator').as_null_object,
      :rake_task_registry => @rake_task_registry,
      :loginator          => double('loginator').as_null_object,
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
end
