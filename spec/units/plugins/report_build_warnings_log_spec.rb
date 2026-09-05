# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'

$: << File.expand_path('../../../../plugins/report_build_warnings_log/lib', __FILE__)
require 'report_build_warnings_log'

PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

describe ReportBuildWarningsLog do
  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator')
    @reportinator = double('reportinator')

    allow(@reportinator).to receive(:generate_heading) { |msg| "HEADING: #{msg}" }
    allow(@reportinator).to receive(:generate_progress) { |msg| "PROGRESS: #{msg}" }
    allow(@loginator).to receive(:log)

    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@warnings, Hash.new)
    @plugin.instance_variable_set(:@mutex, Mutex.new)
    @plugin.instance_variable_set(:@log_filename, 'warnings.log')
    @plugin.instance_variable_set(:@file_wrapper, @file_wrapper)
    @plugin.instance_variable_set(:@loginator, @loginator)
    @plugin.instance_variable_set(:@reportinator, @reportinator)
  end

  # This bail-out is core to the plugin's own purpose (only ever collect
  # output that looks like a warning) and is untouched by the upcoming
  # line-filtering fix -- a line-by-line scan that finds no matching line
  # bails out exactly the same way a whole-output scan that finds no match
  # already does.
  describe '#process_output' do
    it 'stores nothing when output contains no warning-like text, case-insensitively' do
      hash = {}
      @plugin.send(:process_output, :test, "Compiling foo.c...\nLinking...\n", hash)
      expect(hash).to be_empty
    end
  end

  # post_build's public contract -- log a heading, then either report
  # emptiness or write an artifact per context -- survives the upcoming
  # base-class refactor unchanged; only the private plumbing underneath
  # it moves.
  describe '#post_build' do
    it 'logs that no warnings were produced and never touches the filesystem when nothing was collected' do
      expect(@loginator).to receive(:log).with("Build produced no warnings.\n")
      expect(@file_wrapper).not_to receive(:mkdir)
      expect(@file_wrapper).not_to receive(:write)

      @plugin.post_build(0)
    end
  end

  # --- Fixes below this point: written to fail against pre-fix code ---

  describe '#process_output (fix: line-filtering, not whole-blob capture)' do
    it 'stores only the line(s) that actually look like a warning, not the entire tool output' do
      hash = {}
      output = "foo.c: In function 'main':\nfoo.c:3:5: warning: unused variable 'x'\nCompiling foo.c...\n"

      @plugin.send(:process_output, :test, output, hash)

      expect(hash[:test][:collection]).to eq(["foo.c:3:5: warning: unused variable 'x'\n"])
    end
  end

  describe '#post_build (fix: writes via the injected file_wrapper, never a raw File)' do
    it 'joins the collected warning lines for one context and hands them to file_wrapper.write' do
      @plugin.instance_variable_get(:@warnings)[:test] = {
        collection: ["foo.c:3:5: warning: unused variable 'x'\n", "bar.c:9:1: warning: missing return\n"]
      }

      expect(@file_wrapper).to receive(:mkdir).with(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test'))
      expect(@file_wrapper).to receive(:write).with(
        File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test', 'warnings.log'),
        "foo.c:3:5: warning: unused variable 'x'\nbar.c:9:1: warning: missing return\n"
      )

      @plugin.post_build(0)
    end
  end

  describe '#setup (fix: @warnings has no auto-vivifying default block)' do
    it 'builds a plain Hash, so merely reading an absent context can never silently create an entry' do
      configurator = double('configurator')
      allow(configurator).to receive(:report_build_warnings_log_filename).and_return('warnings.log')

      plugin = described_class.allocate
      plugin.instance_variable_set(:@ceedling, {
        configurator: configurator, file_wrapper: @file_wrapper, loginator: @loginator, reportinator: @reportinator
      })
      plugin.setup

      warnings = plugin.instance_variable_get(:@warnings)
      warnings[:some_context_never_written_to]

      expect(warnings).to be_empty
    end
  end
end
