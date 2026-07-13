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
end
