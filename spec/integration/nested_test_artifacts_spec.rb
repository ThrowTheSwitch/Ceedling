# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Per-test logs placed by a test's name, written with real file I/O in a temporary project.
# A test's name is its path from the project root, so its logs sit in subdirectories that
# must exist before anything writes there (GH #1364). Same-named tests keep separate gdb
# logs, each holding only its latest build's crash.

require 'spec_helper'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/build_log_writer'

$LOAD_PATH.unshift( File.expand_path( '../../plugins/report_tests_raw_output_log/lib', __dir__ ) )
$LOAD_PATH.unshift( File.expand_path( '../../plugins/valgrind/lib', __dir__ ) )

# Ceedling runtime path constants the plugins need at require time
PROJECT_BUILD_ROOT           = 'build'              unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts'          unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)
PROJECT_TEST_RESULTS_PATH    = 'build/test/results' unless defined?(PROJECT_TEST_RESULTS_PATH)

require 'report_tests_raw_output_log'
require 'valgrind'

describe 'Per-test logs of nested tests (integration)' do
  let(:loginator)    { double( 'loginator', log: nil ) }
  let(:file_wrapper) { FileWrapper.new( { loginator: loginator, verbosinator: double( 'verbosinator', should_output?: false ) } ) }

  def in_project
    Dir.mktmpdir( 'nested' ) do |root|
      Dir.chdir( root ) do
        stub_const( 'PROJECT_BUILD_ARTIFACTS_ROOT', 'build/artifacts' )
        stub_const( 'VALGRIND_ARTIFACTS_PATH', 'build/artifacts/valgrind' )
        yield
      end
    end
  end

  it 'writes the raw-output log of a test below its root' do
    in_project do
      objects = { file_wrapper: file_wrapper, loginator: loginator, reportinator: double( 'reportinator', generate_heading: '', generate_progress: '' ) }
      plugin  = ReportTestsRawOutputLog.new( objects, 'report_tests_raw_output_log', '/plugins/report_tests_raw_output_log' )

      plugin.post_test_fixture_execute( context: :test, test_name: 'test/unit/test_calc', shell_result: { output: "hello\n" } )
      plugin.post_build( 0 )

      expect( File.read( 'build/artifacts/test/test/unit/test_calc.raw.log' ) ).to include( 'hello' )
    end
  end

  # Valgrind writes its own report at the --log-file path a build hands it
  it "reads the Valgrind report of a test below its root" do
    in_project do
      stub_const( 'TOOLS_VALGRIND', { name: 'valgrind', executable: 'valgrind', arguments: [] } )
      valgrind = Valgrind.allocate
      {
        configurator: double( 'configurator', project_config_hash: {} ), loginator: loginator, file_wrapper: file_wrapper,
        dependinator: double( 'dependinator', register: nil ), mutex: Mutex.new, result_list: [], memory_errors: 0,
        tests_processed: 0, reports_read: 0, explained: []
      }.each { |name, value| valgrind.instance_variable_set( "@#{name}", value ) }

      arg_hash = { context: VALGRIND_SYM, test_name: 'test/unit/test_calc', target: 'build/valgrind/out/test/unit/test_calc/test_calc.out', tool: {} }
      valgrind.pre_test_fixture_register( arg_hash )

      report = arg_hash[:tool][:arguments].find { |argument| argument.start_with?( '--log-file=' ) }[/"(.+)"/, 1]
      File.write( report, "==1== ERROR SUMMARY: 2 errors from 2 contexts\n" )

      valgrind.post_test_fixture_execute( context: VALGRIND_SYM, test_name: 'test/unit/test_calc', result_file: 'test_calc.pass' )

      expect( report ).to eq( 'build/artifacts/valgrind/test/unit/test_calc.log' )
      expect( valgrind.instance_variable_get( :@reports_read ) ).to eq( 1 )
      expect( valgrind.instance_variable_get( :@memory_errors ) ).to eq( 2 )
    end
  end

  it 'keeps the gdb logs of same-named tests apart, each holding only the latest build' do
    in_project do
      paths = FilePathUtils.new( configurator: double( 'configurator', project_log_path: 'build/logs' ), file_wrapper: file_wrapper )
      logs  = ['test/a/test_crash', 'test/b/test_crash'].map { |name| paths.form_test_gdb_log( name, context: :test, name: 'test_boom' ) }

      2.times do |build|
        writer = BuildLogWriter.new( file_wrapper: file_wrapper )
        logs.each { |log| writer.write( log, "=== test_boom ===\nbuild #{build} #{log}\n" ) }
      end

      expect( logs.uniq.size ).to eq( 2 )
      logs.each do |log|
        expect( File.read( log ) ).to eq( "=== test_boom ===\nbuild 1 #{log}\n" )
      end
    end
  end
end
