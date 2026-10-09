# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for the Test Suite Report Log Factory's built-in reports.
#
# Each report is written to a real file and read back with a real parser, so a report a
# CI tool would reject is caught here. The results use a project name and a test path
# full of markup metacharacters, which every format must carry intact. The unit specs
# for each reporter own their structure through in-memory streams.

require 'spec_helper'
require 'json'
require 'tmpdir'
require 'rexml/document'
require 'ceedling/file_wrapper'
require 'ceedling/config/config_walkinator'

$: << File.expand_path('../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'json_tests_reporter'
require 'junit_tests_reporter'
require 'cppunit_tests_reporter'
require 'html_tests_reporter'

describe 'ReportTestsLogFactory reports (integration)' do
  let(:name) { 'Q-36 & "<Modulator>"' }
  let(:test_file) { 'test/T&"x".c' }

  let(:results) do
    {
      times:     { test_file => 0.25 },
      successes: [ { source: { file: test_file }, collection: [ { test: 'test_a', line: 1, message: '', unity_test_time: 0 } ] } ],
      failures:  [ { source: { file: test_file }, collection: [ { test: 'test_<b>', line: 2, message: 'Expected "<a>" & more', unity_test_time: 0 } ] } ],
      ignores:   [ { source: { file: test_file }, collection: [ { test: 'test_c', line: 3, message: '', unity_test_time: 0 } ] } ],
      stdout:    [ { source: { file: test_file }, collection: ['printed <out> & more'] } ],
      counts:    { total: 3, passed: 1, failed: 1, ignored: 1, stdout: 1 },
      total_time: 0.25
    }
  end

  # Writes one report into `dir` and returns its contents
  def report(klass, handle, dir)
    verbosinator = double('verbosinator', should_output?: false)
    reporter = klass.new( handle: handle )
    reporter.config            = {}
    reporter.config_walkinator = ConfigWalkinator.new
    reporter.file_wrapper      = FileWrapper.new( { loginator: double('loginator', log: nil), verbosinator: verbosinator } )
    reporter.setup

    filepath = File.join( dir, reporter.filename )
    reporter.write( name: name, filepath: filepath, results: results, duration_s: 4 )
    File.read( filepath )
  end

  it 'writes a JUnit report that parses, carrying names and messages intact' do
    Dir.mktmpdir do |dir|
      root = REXML::Document.new( report( JunitTestsReporter, :junit, dir ) ).root

      expect(root.attributes['name']).to eq(name)
      expect(root.elements['testsuite'].attributes['name']).to eq('test/T&"x"')
      expect(root.elements['testsuite/testcase/failure'].attributes['message']).to eq('Expected "<a>" & more')
      expect(root.elements['testsuite/system-out'].text).to include('printed <out> & more')
    end
  end

  it 'writes a CppUnit report that parses, carrying names and messages intact' do
    Dir.mktmpdir do |dir|
      root = REXML::Document.new( report( CppunitTestsReporter, :cppunit, dir ) ).root

      expect(root.attributes['name']).to eq(name)
      expect(root.elements['FailedTests/Test/Name'].text).to eq('test/T&"x".c::test_<b>')
      expect(root.elements['FailedTests/Test/Message'].text).to eq('Expected "<a>" & more')
    end
  end

  it 'writes a JSON report that parses, carrying names and messages intact' do
    Dir.mktmpdir do |dir|
      parsed = JSON.parse( report( JsonTestsReporter, :json, dir ) )

      expect(parsed['Name']).to eq(name)
      expect(parsed['BuildDuration']).to eq(4)
      expect(parsed['FailedTests'].first).to include('file' => test_file, 'message' => 'Expected "<a>" & more')
    end
  end

  it 'writes an HTML report with every name and message escaped' do
    Dir.mktmpdir do |dir|
      html = report( HtmlTestsReporter, :html, dir )

      expect(html).to include('<title>Ceedling Test Suite: Q-36 &amp; &quot;&lt;Modulator&gt;&quot;</title>')
      expect(html).to include('test_&lt;b&gt;')
      expect(html).to include('Expected &quot;&lt;a&gt;&quot; &amp; more')
      expect(html).not_to include('<Modulator>')
    end
  end
end
