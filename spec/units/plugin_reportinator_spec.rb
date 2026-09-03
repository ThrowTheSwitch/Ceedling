# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin_reportinator'

describe PluginReportinator do
  before(:each) do
    @plugin_reportinator_helper = double('plugin_reportinator_helper')
    @plugin_manager             = double('plugin_manager')
    @reportinator                = double('reportinator')
    @loginator                      = double('loginator')

    @reportinator_plugin = described_class.new(
      {
        :plugin_reportinator_helper => @plugin_reportinator_helper,
        :plugin_manager             => @plugin_manager,
        :reportinator               => @reportinator,
        :loginator                  => @loginator
      }
    )
  end

  # A build's own test results -- pass or fail -- are core information a user
  # silencing routine build chatter still wants to see, so every plugin that
  # prints post-build test results (report_tests_stdout_plugin, gcov, valgrind)
  # shares this one answer instead of each deciding independently.
  describe '#test_results_floor_verbosity' do
    it 'is ERRORS' do
      expect( @reportinator_plugin.test_results_floor_verbosity ).to eq( Verbosity::ERRORS )
    end
  end
end
