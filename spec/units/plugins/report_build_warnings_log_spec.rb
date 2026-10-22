# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/exceptions'

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
    @plugin.instance_variable_set(:@basename, 'warnings')
    @plugin.instance_variable_set(:@reports, WarningReports.load( [:text], version: '1' ))
    @plugin.instance_variable_set(:@collector, WarningCollector.new)
    @plugin.instance_variable_set(:@file_wrapper, @file_wrapper)
    @plugin.instance_variable_set(:@loginator, @loginator)
    @plugin.instance_variable_set(:@reportinator, @reportinator)
  end

  # Output without warnings still marks its build context as built, so a structured
  # report can say that context had none
  describe '#process_output' do
    it 'stores no warning, only its build context, when output has no warning-like text' do
      hash = {}
      @plugin.send(:process_output, :test, "Compiling foo.c...\nLinking...\n", hash)
      expect(hash[:test][:collection]).to be_empty
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

  # Tool output mixes warnings, their context, and unrelated lines
  describe '#process_output' do
    it 'stores each warning with its context, leaving out unrelated lines' do
      hash = {}
      output = "Compiling foo.c...\nfoo.c: In function 'main':\nfoo.c:3:5: warning: unused variable 'x'\n    3 |   int x;\n"

      @plugin.send(:process_output, :test, output, hash)

      expect(hash[:test][:collection].map( &:text )).to eq(["foo.c: In function 'main':\nfoo.c:3:5: warning: unused variable 'x'\n    3 |   int x;\n"])
    end

    it 'stores a warning reached through a different include chain only once per context' do
      hash = {}
      warning = ->( via ) { "In file included from #{via}:1:\nshared.h:1:12: warning: unused function 'f'\n" }

      @plugin.send(:process_output, :test, warning.call( 'a.c' ), hash)
      @plugin.send(:process_output, :test, warning.call( 'b.c' ), hash)
      @plugin.send(:process_output, :release, warning.call( 'b.c' ), hash)

      expect(hash[:test][:collection].map( &:text )).to eq([warning.call( 'a.c' )])
      expect(hash[:release][:collection].map( &:text )).to eq([warning.call( 'b.c' )])
    end
  end

  # A log reaches disk only through the injected file layer
  describe '#post_build' do
    it 'joins the collected warning lines for one context and hands them to file_wrapper.write' do
      @plugin.instance_variable_get(:@warnings)[:test] = {
        collection: WarningCollector.new.warnings( "foo.c:3:5: warning: unused variable 'x'\nbar.c:9:1: warning: missing return\n" )
      }

      expect(@file_wrapper).to receive(:mkdir).with(File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test'))
      expect(@file_wrapper).to receive(:write).with(
        File.join(PROJECT_BUILD_ARTIFACTS_ROOT, 'test', 'warnings.log'),
        "foo.c:3:5: warning: unused variable 'x'\nbar.c:9:1: warning: missing return\n"
      )

      @plugin.post_build(0)
    end
  end

  describe 'configured matching' do
    def plugin_with(patterns:, excludes:)
      configurator = double( 'configurator', report_build_warnings_log_filename: 'warnings.log', report_build_warnings_log_reports: [],
                             report_build_warnings_log_patterns: patterns, report_build_warnings_log_excludes: excludes )
      plugin = described_class.allocate
      plugin.instance_variable_set(:@ceedling, { configurator: configurator, file_wrapper: @file_wrapper, loginator: @loginator, reportinator: @reportinator })
      plugin.setup
      return plugin
    end

    it 'collects what configured patterns match and drops what excludes match' do
      plugin = plugin_with( patterns: [': remark:'], excludes: ['vendor/'] )
      hash   = {}
      plugin.send(:process_output, :test, "a.c:1:1: remark: kept\nvendor/b.c:2:1: remark: dropped\na.c:3:1: warning: not a remark\n", hash)

      expect(hash[:test][:collection].map( &:text )).to eq( ["a.c:1:1: remark: kept\n"] )
    end

    it 'refuses an invalid pattern as it sets up' do
      expect { plugin_with( patterns: ['bad('], excludes: [] ) }.to raise_error( CeedlingException, /:patterns.*bad\(/ )
    end
  end

  # Each configured report is one artifact per build context, named by the configured
  # filename with the report's own extension
  describe 'configured reports' do
    def plugin_with(filename:, reports:)
      configurator = double( 'configurator', report_build_warnings_log_filename: filename, report_build_warnings_log_reports: reports,
                             report_build_warnings_log_patterns: [], report_build_warnings_log_excludes: [] )
      plugin = described_class.allocate
      plugin.instance_variable_set(:@ceedling, { configurator: configurator, file_wrapper: @file_wrapper, loginator: @loginator, reportinator: @reportinator })
      plugin.setup
      return plugin
    end

    def written
      files = []
      allow(@file_wrapper).to receive(:mkdir)
      allow(@file_wrapper).to receive(:write) { |path, _| files << path }
      return files
    end

    it 'writes every report for a context with warnings, replacing the filename extension' do
      plugin = plugin_with( filename: 'build_warnings.txt', reports: ['sarif', :JSON, :text] )
      files  = written
      plugin.post_compile_execute( context: :test, shell_result: { output: "a.c:1:1: warning: w\n" } )
      plugin.post_build( 0 )

      expect(files).to eq( %w[sarif json log].map { |ext| File.join( 'artifacts', 'test', "build_warnings.#{ext}" ) } )
    end

    it 'writes structured reports but no text log for a context without warnings' do
      plugin = plugin_with( filename: 'warnings', reports: [:text, :sarif] )
      files  = written
      plugin.post_compile_execute( context: :release, shell_result: { output: "Compiling a.c...\n" } )
      plugin.post_build( 0 )

      expect(files).to eq( [File.join( 'artifacts', 'release', 'warnings.sarif' )] )
    end

    it 'says the build produced no warnings, and writes nothing, when only the text log is configured' do
      plugin = plugin_with( filename: 'warnings', reports: [] )
      files  = written
      expect(@loginator).to receive(:log).with( "Build produced no warnings.\n" )
      plugin.post_compile_execute( context: :test, shell_result: nil )
      plugin.post_build( 0 )

      expect(files).to be_empty
    end

    it 'refuses an unknown report as it sets up' do
      expect { plugin_with( filename: 'warnings', reports: [:xml] ) }.to raise_error( CeedlingException, /`xml`/ )
    end
  end

  describe '#setup' do
    it 'builds a plain Hash, so merely reading an absent context can never silently create an entry' do
      configurator = double('configurator')
      allow(configurator).to receive(:report_build_warnings_log_filename).and_return('warnings.log')
      allow(configurator).to receive(:report_build_warnings_log_patterns).and_return([])
      allow(configurator).to receive(:report_build_warnings_log_excludes).and_return([])
      allow(configurator).to receive(:report_build_warnings_log_reports).and_return([:text])

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
