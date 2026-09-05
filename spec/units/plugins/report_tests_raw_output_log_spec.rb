# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'

$: << File.expand_path('../../../../plugins/report_tests_raw_output_log/lib', __FILE__)
require 'report_tests_raw_output_log'

PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

describe ReportTestsRawOutputLog do
  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator')
    @reportinator = double('reportinator')

    allow(@reportinator).to receive(:generate_heading) { |msg| "HEADING: #{msg}" }
    allow(@reportinator).to receive(:generate_progress) { |msg| "PROGRESS: #{msg}" }
    allow(@loginator).to receive(:log)

    @plugin = described_class.allocate
    @plugin.instance_variable_set(:@raw_output, {})
    @plugin.instance_variable_set(:@mutex, Mutex.new)
    @plugin.instance_variable_set(:@file_wrapper, @file_wrapper)
    @plugin.instance_variable_set(:@loginator, @loginator)
    @plugin.instance_variable_set(:@reportinator, @reportinator)
  end

  # extract_output's own line-scan (skip blank lines, skip test-result
  # lines, stop at the summary footer) is untouched by this pass -- it's
  # the exact shape the warnings-log fix adapts -- so this pins real,
  # nontrivial parsing behavior that must survive the shared-base refactor.
  describe '#extract_output' do
    it 'keeps stray console output while skipping blank lines, test-result lines, and everything after the footer' do
      raw = <<~OUTPUT
        test/TestFoo.c:10:test_something:PASS

        Debug: entering state X
        test/TestFoo.c:20:test_other:FAIL
        -----------------------
        TESTED:  2
      OUTPUT

      output = @plugin.send(:extract_output, raw)

      expect(output).to eq(["Debug: entering state X\n"])
    end

    it 'returns an empty array when there is no extra output at all' do
      raw = <<~OUTPUT
        test/TestFoo.c:10:test_something:PASS
        -----------------------
        TESTED:  1
      OUTPUT

      expect(@plugin.send(:extract_output, raw)).to eq([])
    end
  end

  describe '#post_build' do
    it 'logs that no extra output was produced and never touches the filesystem when nothing was collected' do
      expect(@loginator).to receive(:log).with("Tests produced no extra console output.\n")
      expect(@file_wrapper).not_to receive(:mkdir)
      expect(@file_wrapper).not_to receive(:write)

      @plugin.post_build(0)
    end
  end

  # --- Fix below this point: written to fail against pre-fix code ---

  describe '#post_build (fix: writes via the injected file_wrapper, never a raw File)' do
    it 'joins one test executable\'s collected output lines and hands them to file_wrapper.write' do
      @plugin.instance_variable_get(:@raw_output)[:test] = {
        'TestFoo' => ["Debug: entering state X\n", "Debug: leaving state X\n"]
      }

      expect(@file_wrapper).to receive(:mkdir).with(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test'))
      expect(@file_wrapper).to receive(:write).with(
        File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test', 'TestFoo.raw.log'),
        "Debug: entering state X\nDebug: leaving state X\n"
      )

      @plugin.post_build(0)
    end
  end
end
