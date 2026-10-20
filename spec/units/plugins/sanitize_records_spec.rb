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
    # A crash's notice names its finding already
    it 'logs all but the finding a crash explanation names' do
      records.record( :sanitize, 'test_a', [finding( 9 ), finding( 14 )], explained: finding( 9 ) )

      expect(loginator).to have_received(:log).once
      expect(loginator).to have_received(:log).with( /line 14|test_a\.c:14/, anything, anything )
      expect(file_wrapper).to have_received(:write).once
      expect(records.failure_message).to eq( 'Sanitizers found 2 problems in 1 test' )
    end

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
  # The build failure names the reports written, as other plugins' failures do
  describe '#failure_message' do
    def report(extension, write_empty)
      return double( extension, extension: extension, write_empty?: write_empty, render: '' )
    end

    let(:reports) { [report( 'log', false ), report( 'json', true )] }
    let(:records) { described_class.new( file_wrapper: file_wrapper, loginator: loginator, reports: reports ) }
    let(:dir)     { File.join( SANITIZE_ARTIFACTS_PATH, 'sanitize' ) }

    it 'names the reports written in their directory' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.write_reports( :sanitize )

      expect(records.failure_message).to eq( "Sanitizers found 1 problem in 1 test. See the reports in #{dir}: sanitize.log, sanitize.json." )
    end

    it 'names each directory\'s reports for each instrumented build' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.record( :test, 'test_a', [finding( 9 )] )
      records.write_reports( :sanitize )
      records.write_reports( :test )

      test_dir = File.join( SANITIZE_ARTIFACTS_PATH, 'test' )
      expect(records.failure_message).to eq(
        "Sanitizers found 2 problems in 1 test. See the reports in #{dir}: sanitize.log, sanitize.json; #{test_dir}: sanitize.log, sanitize.json."
      )
    end

    it 'names a report rewritten for the same build once' do
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      2.times { records.write_reports( :sanitize ) }

      expect(records.failure_message).to eq( "Sanitizers found 1 problem in 1 test. See the reports in #{dir}: sanitize.log, sanitize.json." )
    end

    it 'names no reports when none are written' do
      records = described_class.new( file_wrapper: file_wrapper, loginator: loginator, reports: [] )
      records.record( :sanitize, 'test_a', [finding( 9 )] )
      records.write_reports( :sanitize )

      expect(records.failure_message).to eq( 'Sanitizers found 1 problem in 1 test' )
    end
  end
end
