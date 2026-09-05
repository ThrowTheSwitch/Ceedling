# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/config/config_walkinator'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'report_tests_log_factory'

describe ReportTestsLogFactory do
  before(:each) do
    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@ceedling, { config_walkinator: ConfigWalkinator.new })
  end

  describe '#load_reporters' do
    it 'builds a working instance of a known built-in reporter, with its own configuration injected' do
      reporters = @plugin.send(:load_reporters, ['json'], { json: { filename: 'custom.json' } })

      expect(reporters.length).to eq(1)
      expect(reporters.first).to be_a(JsonTestsReporter)
      expect(reporters.first.filename).to eq('custom.json')
    end
  end

  describe '#generate_report_name' do
    before(:each) do
      configurator = double('configurator')
      allow(configurator).to receive(:project_name).and_return('MyProject')
      @plugin.instance_variable_get(:@ceedling)[:configurator] = configurator
    end

    it 'uses the project name unprefixed for the default test context' do
      expect(@plugin.send(:generate_report_name, TEST_SYM)).to eq('MyProject')
    end

    it 'prefixes with the bracketed, uppercased context for any non-default context' do
      expect(@plugin.send(:generate_report_name, :gcov)).to eq('[GCOV] MyProject')
    end
  end
end
