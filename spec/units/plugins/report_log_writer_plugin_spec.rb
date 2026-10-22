# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/plugins/report_log_writer_plugin'

# Ceedling normally derives this from project configuration at runtime; the
# `unless defined?` guard matches the convention already used by other
# plugin specs (e.g. cppcheck_spec.rb) that need this constant present.
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

# Exercises the shared base directly (not a real subclass) -- proves the
# mutex/heading/write plumbing correct in isolation before either
# ReportBuildWarningsLog or ReportTestsRawOutputLog is wired onto it.
describe ReportLogWriterPlugin do
  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator')
    @reportinator = double('reportinator')

    allow(@reportinator).to receive(:generate_heading) { |msg| "HEADING: #{msg}" }
    allow(@reportinator).to receive(:generate_progress) { |msg| "PROGRESS: #{msg}" }
    allow(@loginator).to receive(:log)

    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@mutex, Mutex.new)
    @plugin.instance_variable_set(:@file_wrapper, @file_wrapper)
    @plugin.instance_variable_set(:@loginator, @loginator)
    @plugin.instance_variable_set(:@reportinator, @reportinator)
  end

  describe '#artifact_filepath' do
    it 'ensures the per-context artifact directory exists and returns the joined filepath' do
      expect(@file_wrapper).to receive(:mkdir).with(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test'))

      filepath = @plugin.send(:artifact_filepath, :test, 'warnings.log')

      expect(filepath).to eq(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test', 'warnings.log'))
    end
  end

  describe '#flush_log' do
    it 'logs the empty message and never runs the block when empty: reports true' do
      expect(@loginator).to receive(:log).with('HEADING: Some Report')
      expect(@loginator).to receive(:log).with("Nothing collected.\n")
      expect(@loginator).not_to receive(:log).with('')

      ran_block = false
      @plugin.send(:flush_log, heading: 'Some Report', empty_message: 'Nothing collected.', empty: -> { true }) do
        ran_block = true
      end

      expect(ran_block).to be false
    end

    it 'runs the block and logs trailing whitespace when empty: reports false' do
      expect(@loginator).to receive(:log).with('HEADING: Some Report')
      expect(@loginator).to receive(:log).with('')

      ran_block = false
      @plugin.send(:flush_log, heading: 'Some Report', empty_message: 'Nothing collected.', empty: -> { false }) do
        ran_block = true
      end

      expect(ran_block).to be true
    end

    it "evaluates the empty check and runs the block under the same mutex, so a build thread's write can never interleave with this read" do
      # A real race would deadlock or corrupt state under this same mutex --
      # this only proves both sides use it, not that it's impossible to get
      # wrong, but a regression removing either synchronize would show up
      # here as a NoMethodError once @mutex is replaced by a non-reentrant
      # double, or as a flaky failure under a build thread stress test.
      expect(@plugin.instance_variable_get(:@mutex)).to receive(:synchronize).twice.and_call_original

      @plugin.send(:flush_log, heading: 'Some Report', empty_message: 'Nothing collected.', empty: -> { false }) {}
    end
  end

  describe '#write_artifact' do
    it 'logs progress and writes contents via the injected file_wrapper' do
      expect(@loginator).to receive(:log).with('PROGRESS: Generating artifact artifacts/test/warnings.log')
      expect(@file_wrapper).to receive(:write).with('artifacts/test/warnings.log', "line one\nline two\n")

      @plugin.send(:write_artifact, 'artifacts/test/warnings.log', "line one\nline two\n")
    end
  end
end
