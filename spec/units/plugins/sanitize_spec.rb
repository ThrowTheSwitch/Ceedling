# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'shellwords'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'

PROJECT_BUILD_ROOT           = 'build'           unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'build/artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)
EXTENSION_ASSEMBLY           = /\.s\z/           unless defined?(EXTENSION_ASSEMBLY)

TOOLS_SANITIZE_FIXTURE = {
  :executable => 'env',
  :name       => 'default_sanitize_fixture',
  :optional   => true,
  :arguments  => []
}.freeze unless defined?(TOOLS_SANITIZE_FIXTURE)

$: << File.expand_path('../../../../plugins/sanitize/lib', __FILE__)
require 'sanitize'

describe Sanitize do
  def report(name)
    File.read( File.expand_path( "../../../support/fixtures/sanitizer_reports/#{name}.txt", __FILE__ ) )
  end

  let(:defaults) do
    { sanitizers: ['address', 'undefined'], recover: false, detect_leaks: true, test_builds: false, fail_build: true,
      reports: [], runtime_options: {}, flags: {} }
  end

  let(:loginator)      { double('loginator', log: nil) }
  let(:dependinator)   { double('dependinator', register: nil) }
  let(:file_wrapper)   { double('file_wrapper', write: nil, mkdir: nil) }
  let(:plugin_manager) { double('plugin_manager', register_build_failure: nil) }
  let(:tracker)        { double('rake_invocation_tracker', invoked?: true) }
  let(:tool_validator) { double('tool_validator', validate: nil) }
  let(:system_wrapper) { double('system_wrapper', windows?: false, macos?: false) }
  let(:plugin_reportinator) { double('plugin_reportinator', assemble_test_results: {}, run_test_results_report: nil, test_results_floor_verbosity: 3) }

  def build(overrides = {})
    configurator = double( 'configurator', plugins_display_raw_test_results: true )
    setupinator  = double( 'setupinator', config_hash: { sanitize: defaults.merge( overrides ) } )
    system_objects = {
      configurator: configurator, setupinator: setupinator, loginator: loginator, dependinator: dependinator,
      file_wrapper: file_wrapper, plugin_manager: plugin_manager, rake_invocation_tracker: tracker,
      tool_validator: tool_validator, system_wrapper: system_wrapper, plugin_reportinator: plugin_reportinator,
      reportinator: double( 'reportinator', generate_progress: 'PROGRESS' )
    }
    return described_class.new( system_objects, 'sanitize', '/plugins/sanitize' )
  end

  describe '#setup' do
    it 'rejects a :test_builds setting that is not a boolean' do
      expect { build( test_builds: 'yes' ) }.to raise_error( CeedlingException, /:sanitize ↳ :test_builds must be TRUE or FALSE/ )
    end

    it 'rejects an unknown sanitizer' do
      expect { build( sanitizers: ['thread'] ) }.to raise_error( CeedlingException, /:sanitize ↳ :sanitizers entry `thread`/ )
    end
  end

  describe '#validate_environment!' do
    it 'stops on Windows, which the sanitizers do not support here' do
      allow(system_wrapper).to receive(:windows?).and_return( true )
      expect { build.validate_environment! }.to raise_error( CeedlingException, /not supported on Windows/ )
    end

    it 'checks the fixture tool' do
      build.validate_environment!
      expect(tool_validator).to have_received(:validate).with( tool: TOOLS_SANITIZE_FIXTURE, boom: true )
    end
  end

  # An instrumented test: build runs through no sanitize: task, so the build itself checks
  describe '#pre_test_build' do
    it 'checks the platform and tools for an instrumented test: build' do
      allow(system_wrapper).to receive(:windows?).and_return( true )
      expect { build( test_builds: true ).pre_test_build( TEST_SYM, 0 ) }.to raise_error( CeedlingException, /not supported on Windows/ )
    end

    it 'leaves an uninstrumented test: build unchecked' do
      allow(system_wrapper).to receive(:windows?).and_return( true )
      expect { build.pre_test_build( TEST_SYM, 0 ) }.to_not raise_error
    end

    it 'checks only once' do
      sanitize = build( test_builds: true )
      sanitize.pre_test_build( TEST_SYM, 0 )
      sanitize.pre_test_build( SANITIZE_SYM, 0 )

      expect(tool_validator).to have_received(:validate).once
    end
  end

  # Flags go only where the plugin instruments, so other plugins' builds stay clean
  describe 'compile and link flags' do
    def compile(sanitize, context, source: 'src/buffer.c')
      arg_hash = { context: context, flags: ['-g'], source: source, object: 'build/buffer.o' }
      sanitize.pre_test_compile_register( arg_hash )
      return arg_hash[:flags]
    end

    it 'instruments a sanitize: build\'s compiles and links' do
      sanitize = build
      arg_hash = { context: SANITIZE_SYM, flags: [], executable: 'build/test_a.out' }
      sanitize.pre_test_link_register( arg_hash )

      expect(compile( sanitize, SANITIZE_SYM )).to include( '-fsanitize=address,undefined', '-fno-sanitize-recover=all' )
      expect(arg_hash[:flags]).to eq( ['-fsanitize=address,undefined'] )
    end

    it 'leaves ordinary test: builds alone unless asked to instrument them' do
      expect(compile( build, :test )).to eq( ['-g'] )
      expect(compile( build( test_builds: true ), :test )).to include( '-fsanitize=address,undefined' )
    end

    it 'never instruments another plugin\'s build' do
      sanitize = build( test_builds: true )
      [:gcov, :bullseye, :valgrind].each { |context| expect(compile( sanitize, context )).to eq( ['-g'] ) }
    end

    it 'leaves assembly sources alone' do
      expect(compile( build, SANITIZE_SYM, source: 'src/startup.s' )).to eq( ['-g'] )
    end

    it 'records its settings with each object, so changing them rebuilds it' do
      compile( build, SANITIZE_SYM )
      expect(dependinator).to have_received(:register).with( 'build/buffer.o', meta: { sanitize: hash_including( sanitizers: ['address', 'undefined'] ) } )
    end

    # Reporting and failing the build change nothing a build or test run produces
    it 'leaves out the settings that change only reporting' do
      compile( build( reports: [:sarif], fail_build: false ), SANITIZE_SYM )
      expect(dependinator).to have_received(:register).with(
        'build/buffer.o', meta: { sanitize: { sanitizers: ['address', 'undefined'], recover: false, detect_leaks: true, runtime_options: {}, flags: {} } }
      )
    end
  end

  describe '#pre_test_fixture_register' do
    def register(sanitize, tool: { name: 'default_test_fixture', executable: '${1}', arguments: [] }, context: SANITIZE_SYM)
      arg_hash = { context: context, tool: tool, target: 'build/test_a.out', test_name: 'test_a' }
      sanitize.pre_test_fixture_register( arg_hash )
      return arg_hash[:tool]
    end

    it 'runs the test executable with each sanitizer\'s options set for it alone' do
      tool = register( build )

      expect(tool[:executable]).to eq( 'env' )
      expect(tool[:arguments]).to eq( [
        "ASAN_OPTIONS='halt_on_error=1:exitcode=0:detect_leaks=1'",
        "UBSAN_OPTIONS='halt_on_error=1:print_stacktrace=1:exitcode=0'",
        '${1}'
      ] )
    end

    # The fixture command runs in a shell, which must pass an option value through intact. The
    # plugin, like this example, needs a POSIX shell, which Windows lacks.
    it 'quotes each option so a shell passes its value through as written',
       skip: (RUBY_PLATFORM.match?( /mswin|mingw/ ) ? 'needs a POSIX shell, as the plugin does' : false) do
      tool  = register( build( runtime_options: { asan: ["suppressions=/my dir/$HOME/it's \"ok\"`date`"] } ) )
      value = `sh -c #{Shellwords.escape( "env #{tool[:arguments].first} sh -c 'printf %s \"$ASAN_OPTIONS\"'" )}`

      expect(value).to end_with( ":suppressions=/my dir/$HOME/it's \"ok\"`date`" )
    end

    # A backtrace rerun then runs with the same options as the main run
    it 'asks for backtrace reruns to run through it' do
      expect(register( build )[:backtrace_rerun]).to eq( true )
    end

    it 'wraps a project\'s own fixture tool, its executable and arguments after the options' do
      tool = register( build, tool: { name: 'sim', executable: 'simulator', arguments: ['--quiet', '${1}'] } )
      expect(tool[:arguments].last( 3 )).to eq( ['simulator', '--quiet', '${1}'] )
    end

    it 'leaves another build\'s fixture tool alone' do
      original = { name: 'default_test_fixture', executable: '${1}', arguments: [] }
      expect(register( build, tool: original, context: :test )).to equal( original )
    end
  end

  describe 'findings' do
    def execute(sanitize, stderr, context: SANITIZE_SYM)
      sanitize.post_test_fixture_execute(
        { context: context, test_name: 'test_a', result_file: 'build/sanitize/results/test_a.pass', shell_result: { stderr: stderr } }
      )
    end

    it 'writes a test\'s sanitizer report to its own log and logs each finding' do
      execute( build, report( 'gcc_heap' ) )

      expect(file_wrapper).to have_received(:write).with( File.join( SANITIZE_ARTIFACTS_PATH, 'sanitize', 'test_a.log' ), /heap-buffer-overflow/, 'w' )
      expect(loginator).to have_received(:log).with( /test_a: AddressSanitizer heap-buffer-overflow at \/x\/heap\.c:3/, Verbosity::ERRORS, LogLabels::ERROR )
    end

    it 'writes nothing for a test without findings' do
      execute( build, '' )
      expect(file_wrapper).not_to have_received(:write)
    end

    # A test reported from the last build's results was not run
    it 'reads nothing for a test whose cached results were reported' do
      sanitize = build
      expect { sanitize.post_test_fixture_execute( { context: SANITIZE_SYM, test_name: 'test_a', result_file: 'x.pass', shell_result: nil } ) }.to_not raise_error
    end

    it 'names a crash\'s finding and its log' do
      sanitize = build
      arg_hash = { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: report( 'gcc_heap' ) }, explanation: nil }
      sanitize.explain_test_crash( arg_hash )

      log = File.join( SANITIZE_ARTIFACTS_PATH, 'sanitize', 'test_a.log' )
      expect(arg_hash[:explanation_heading]).to eq( 'was stopped by a sanitizer finding' )
      expect(arg_hash[:explanation]).to eq( 'AddressSanitizer heap-buffer-overflow at /x/heap.c:3' )
      expect(arg_hash[:explanation_details]).to eq( ["Boom log: #{log}"] )
    end

    # A test case after the one that halted the main run runs only in its rerun
    it 'counts the finding it names, so a rerun-only finding fails the build' do
      sanitize = build
      sanitize.explain_test_crash( { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: report( 'gcc_heap' ) }, explanation: nil } )
      sanitize.post_build( 0 )

      expect(plugin_manager).to have_received(:register_build_failure).with( SANITIZE_SYM, /Sanitizers found 1 problem in 1 test/ )
    end

    it 'logs no separate line for the finding a crash notice names' do
      sanitize = build
      sanitize.explain_test_crash( { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: report( 'gcc_heap' ) }, explanation: nil, crash_notice: true } )
      expect(loginator).not_to have_received(:log).with( /test_a: AddressSanitizer/, anything, anything )
    end

    # A backtrace rerun's explanation reaches no crash notice
    it 'logs the finding a backtrace rerun\'s explanation names' do
      sanitize = build
      sanitize.explain_test_crash( { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: report( 'gcc_heap' ) }, explanation: nil, crash_notice: false } )
      expect(loginator).to have_received(:log).with( /test_a: AddressSanitizer/, anything, anything )
    end

    it 'counts a finding once when both the main run and its explanation report it' do
      sanitize = build
      sanitize.explain_test_crash( { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: report( 'gcc_heap' ) }, explanation: nil } )
      sanitize.post_test_fixture_execute( { context: SANITIZE_SYM, test_name: 'test_a', result_file: 'x.pass', shell_result: { stderr: report( 'gcc_heap' ) } } )
      sanitize.post_build( 0 )

      expect(plugin_manager).to have_received(:register_build_failure).with( SANITIZE_SYM, /Sanitizers found 1 problem in 1 test/ )
    end

    it 'names nothing for a crash without a sanitizer report' do
      arg_hash = { context: SANITIZE_SYM, test_name: 'test_a', shell_result: { stderr: 'Segmentation fault' }, explanation: nil }
      build.explain_test_crash( arg_hash )

      expect(arg_hash[:explanation]).to be_nil
    end
  end

  describe '#post_build' do
    def build_after(stderr, **overrides)
      sanitize = build( overrides )
      sanitize.post_test_fixture_execute( { context: SANITIZE_SYM, test_name: 'test_a', result_file: 'x.pass', shell_result: { stderr: stderr } } )
      sanitize.post_build( 0 )
      return sanitize
    end

    it 'fails the build when a sanitizer found something' do
      build_after( report( 'gcc_leak' ) )
      expect(plugin_manager).to have_received(:register_build_failure).with( SANITIZE_SYM, /Sanitizers found 1 problem in 1 test/ )
    end

    it 'leaves the build alone when asked not to fail it' do
      build_after( report( 'gcc_leak' ), fail_build: false )
      expect(plugin_manager).not_to have_received(:register_build_failure)
    end

    it 'leaves a build without findings alone' do
      build_after( '' )
      expect(plugin_manager).not_to have_received(:register_build_failure)
    end

    # The build failure summary names the reports, so the findings aren't logged again
    it 'logs no tally after the build' do
      build_after( report( 'gcc_leak' ), reports: [:json] )
      expect(loginator).not_to have_received(:log).with( /Sanitizer (findings|reports):/, anything )
    end

    it 'writes each configured report for each instrumented build' do
      build_after( report( 'gcc_leak' ), reports: [:json] )
      expect(file_wrapper).to have_received(:write).with( File.join( SANITIZE_ARTIFACTS_PATH, 'sanitize', 'sanitize.json' ), /"memory-leak"/ )
    end
  end
end
