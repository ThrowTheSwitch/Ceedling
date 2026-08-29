# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin_manager'

describe PluginManager do
  before(:each) do
    @configurator          = double('configurator', :plugins_display_raw_test_results => false)
    @plugin_manager_helper = double('plugin_manager_helper')
    @loginator             = double('loginator')
    @reportinator          = double('reportinator')
    @system_wrapper        = double('system_wrapper')

    @pm = described_class.new(
      :configurator          => @configurator,
      :plugin_manager_helper => @plugin_manager_helper,
      :loginator             => @loginator,
      :reportinator          => @reportinator,
      :system_wrapper        => @system_wrapper
    )
  end

  describe '#post_test_fixture_execute' do
    it 'registers a build failure when tests fail' do
      arg_hash = { :context => TEST_SYM, :shell_result => { :output => '' }, :results => { :counts => { :failed => 1 } } }
      @pm.post_test_fixture_execute(arg_hash)
      expect(@pm.plugins_failed?).to be(true)
    end

    it 'does not register a build failure when all tests pass' do
      arg_hash = { :context => TEST_SYM, :shell_result => { :output => '' }, :results => { :counts => { :failed => 0 } } }
      @pm.post_test_fixture_execute(arg_hash)
      expect(@pm.plugins_failed?).to be(false)
    end

    it 'does not register a build failure when result counts are absent' do
      arg_hash = { :context => TEST_SYM, :shell_result => { :output => '' }, :results => {} }
      @pm.post_test_fixture_execute(arg_hash)
      expect(@pm.plugins_failed?).to be(false)
    end
  end

  # These fire ahead of TestBuildExecutor's own dependency-tracker meta capture (see
  # TestBuildExecutor's resolve_compile_tool/resolve_link_tool/resolve_fixture_tool) --
  # distinct from and additional to the existing pre_compile_execute/pre_link_execute/
  # pre_test_fixture_execute hooks, which only fire for a target actually rebuilt.
  describe 'pre_compile_register / pre_link_register / pre_test_fixture_register' do
    before(:each) do
      allow(@loginator).to receive(:lazy)
    end

    def stub_plugin_implementing(method)
      plugin = double('plugin', :name => 'fake')
      allow(plugin).to receive(:respond_to?).and_return(false)
      allow(plugin).to receive(:respond_to?).with(method).and_return(true)
      @pm.instance_variable_set(:@plugin_objects, [plugin])
      plugin
    end

    it 'dispatches pre_compile_register to a plugin implementing it, with the given arg_hash' do
      plugin = stub_plugin_implementing(:pre_compile_register)
      arg_hash = { tool: 'fake tool' }

      expect(plugin).to receive(:pre_compile_register).with(arg_hash)
      @pm.pre_compile_register(arg_hash)
    end

    it 'dispatches pre_link_register to a plugin implementing it, with the given arg_hash' do
      plugin = stub_plugin_implementing(:pre_link_register)
      arg_hash = { tool: 'fake tool' }

      expect(plugin).to receive(:pre_link_register).with(arg_hash)
      @pm.pre_link_register(arg_hash)
    end

    it 'dispatches pre_test_fixture_register to a plugin implementing it, with the given arg_hash' do
      plugin = stub_plugin_implementing(:pre_test_fixture_register)
      arg_hash = { tool: 'fake tool' }

      expect(plugin).to receive(:pre_test_fixture_register).with(arg_hash)
      @pm.pre_test_fixture_register(arg_hash)
    end

    it 'is a harmless no-op for any of the three when no plugin implements it' do
      expect { @pm.pre_compile_register({}) }.to_not raise_error
      expect { @pm.pre_link_register({}) }.to_not raise_error
      expect { @pm.pre_test_fixture_register({}) }.to_not raise_error
    end
  end
end
