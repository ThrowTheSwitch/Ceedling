# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'

PROJECT_BUILD_ARTIFACTS_ROOT = 'build/artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/sanitize/lib', __FILE__)
require 'sanitize_findings'
require 'sanitize_records'

describe SanitizeRecords do
  let(:file_wrapper) { double('file_wrapper', mkdir: nil, write: nil) }
  let(:loginator)    { double('loginator', log: nil) }
  let(:records)      { described_class.new( file_wrapper: file_wrapper, loginator: loginator, reports: [] ) }
  let(:log)          { described_class.log_filepath( :sanitize, 'test_a' ) }

  def finding(line, text: "report at line #{line}\n")
    return SanitizeFindings::Finding.new( sanitizer: :address, kind: 'heap-buffer-overflow', file: 'test/test_a.c', line: line, message: 'overflow', text: text )
  end

  # A crashed test's reruns reproduce the main run's finding, and reach findings it never did
  describe '#record' do
    it 'counts a finding recorded again only once' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.record( :sanitize, 'test_a', [finding( 9 )] )

      expect(records.failure_message).to eq( 'Sanitizers found 1 problem in 1 test' )
      expect(loginator).to have_received(:log).once
    end

    it 'counts each distinct finding' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.record( :sanitize, 'test_a', [finding( 14 )] )

      expect(records.failure_message).to eq( 'Sanitizers found 2 problems in 1 test' )
    end

    # A build's first report for a test replaces the last build's log
    it 'starts a test\'s log with its first report and adds each new one after it' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.record( :sanitize, 'test_a', [finding( 9 ), finding( 14 )] )

      expect(file_wrapper).to have_received(:write).with( log, "report at line 9\n", 'w' ).ordered
      expect(file_wrapper).to have_received(:write).with( log, "\nreport at line 14\n", 'a' ).ordered
    end

    it 'writes nothing more for a finding already recorded' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.record( :sanitize, 'test_a', [finding( 9 )] )

      expect(file_wrapper).to have_received(:write).once
    end
  end
end
