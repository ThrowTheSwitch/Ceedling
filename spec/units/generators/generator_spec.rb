# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator'
require 'ceedling/constants'

# Scoped to Generator#generate_object_file_c's choice of which file the compiler receives,
# and to where Generator#generate_mock has CMock write a mock.
describe Generator do
  before(:each) do
    @tool_executor  = double('tool_executor')
    @plugin_manager = double('plugin_manager')

    allow(@tool_executor).to receive(:build_command_line).and_return( { line: 'gcc', options: {} } )
    allow(@tool_executor).to receive(:exec).and_return( { output: '', exit_code: 0 } )
    allow(@plugin_manager).to receive(:pre_compile_execute)
    allow(@plugin_manager).to receive(:post_compile_execute)

    @collaborators = collaborators = [
      :configurator, :generator_helper, :generator_mocks, :generator_test_results,
      :generator_test_results_backtrace, :generator_partials, :test_context_extractor,
      :file_finder, :file_path_utils, :reportinator, :loginator, :test_runner_manager,
      :system_wrapper, :file_wrapper
    ].to_h { |name| [name, double( name.to_s ).as_null_object] }

    @generator_mocks = double('generator_mocks')
    @cmock           = double('cmock', setup_mocks: nil)
    allow(@generator_mocks).to receive(:build_configuration).and_return( {} )
    allow(@generator_mocks).to receive(:manufacture).and_return( @cmock )
    allow(@plugin_manager).to receive(:pre_mock_generate)
    allow(@plugin_manager).to receive(:post_mock_generate)

    @generator = described_class.new(
      collaborators.merge( tool_executor: @tool_executor, plugin_manager: @plugin_manager, generator_mocks: @generator_mocks )
    )
  end

  def compile(**extra)
    @generator.generate_object_file_c(
      tool: :compiler, module_name: 'test_gpio', context: :test,
      source: 'src/gpio.c', object: 'build/gpio.o', **extra
    )
  end

  describe '#generate_object_file_c' do
    it 'hands the compiler the source itself by default' do
      compile()

      expect(@tool_executor).to have_received(:build_command_line).with( :compiler, [], 'src/gpio.c', any_args )
    end

    # An isolated copy is what compiles, but plugins and logs report the real source.
    it 'hands the compiler compile_source while plugins still see the original source' do
      compile( compile_source: 'build/tmp1/gpio.c' )

      expect(@tool_executor).to have_received(:build_command_line).with( :compiler, [], 'build/tmp1/gpio.c', any_args )
      expect(@plugin_manager).to have_received(:pre_compile_execute).with( hash_including( source: 'src/gpio.c' ) )
      expect(@plugin_manager).to have_received(:post_compile_execute).with( hash_including( source: 'src/gpio.c' ) )
    end
  end

  describe '#generate_test_results' do
    before(:each) do
      allow(@collaborators[:generator_helper]).to receive(:test_crash?).and_return( false )
      allow(@collaborators[:test_runner_manager]).to receive(:collect_cmdline_args).and_return( ['-n test_a'] )
      allow(@plugin_manager).to receive(:pre_test_fixture_execute)
      allow(@plugin_manager).to receive(:post_test_fixture_execute)
    end

    # A fixture tool that wraps the test executable runs it as its own last argument
    it 'hands the fixture tool Unity\'s test case filters after its own arguments' do
      @generator.generate_test_results(
        tool: :fixture, context: :test, test_name: 'test_a', test_filepath: 'test/test_a.c',
        executable: 'build/test_a.out', result: 'build/test_a.pass'
      )

      expect(@tool_executor).to have_received(:build_command_line).with( :fixture, [], 'build/test_a.out', trailing: ['-n test_a'] )
    end
  end

  describe '#generate_test_results with a crash' do
    let(:backtrace) { @collaborators[:generator_test_results_backtrace] }
    let(:results)   { @collaborators[:generator_test_results] }

    def run(tool: :fixture, use_backtrace: :none, explanation: nil, details: nil, heading: nil)
      allow(@collaborators[:configurator]).to receive(:project_config_hash).and_return( { project_use_backtrace: use_backtrace } )
      allow(@plugin_manager).to receive(:explain_test_crash) do |arg_hash|
        arg_hash[:explanation] = explanation
        arg_hash[:explanation_details] = details
        arg_hash[:explanation_heading] = heading
      end

      @generator.generate_test_results(
        tool: tool, context: :test, test_name: 'test_a', test_filepath: 'test/test_a.c',
        executable: 'build/test_a.out', result: 'build/test_a.pass'
      )
    end

    before(:each) do
      allow(@collaborators[:generator_helper]).to receive(:test_crash?).and_return( true )
      allow(@collaborators[:test_context_extractor]).to receive(:lookup_test_cases).and_return( [] )
      allow(results).to receive(:filter_test_cases) { |cases| cases }
      allow(@plugin_manager).to receive(:pre_test_fixture_execute)
      allow(@plugin_manager).to receive(:post_test_fixture_execute)
    end

    it 'fails a crashed test with the cause a plugin names for it' do
      run( explanation: 'ASan heap-buffer-overflow at src/a.c:9' )
      expect(results).to have_received(:create_crash_failure).with( 'test_a.c', anything, [], message: 'ASan heap-buffer-overflow at src/a.c:9' )
    end

    it 'fails a crashed test with the cause\'s details alongside it' do
      run( explanation: 'ASan heap-buffer-overflow at src/a.c:9', details: ['Boom log: x.log'] )
      expect(results).to have_received(:create_crash_failure).with( 'test_a.c', anything, [], message: 'ASan heap-buffer-overflow at src/a.c:9 (Boom log: x.log)' )
    end

    it 'logs a plugin\'s explanation in place of the generic crash notice' do
      run( explanation: 'ASan heap-buffer-overflow at src/a.c:9', details: ['Boom log: x.log'], heading: 'was stopped by a sanitizer finding' )

      explanation = { heading: 'was stopped by a sanitizer finding', cause: 'ASan heap-buffer-overflow at src/a.c:9', details: ['Boom log: x.log'] }
      expect(@collaborators[:generator_helper]).to have_received(:log_explained_crash).with( 'build/test_a.out', explanation )
      expect(@collaborators[:generator_helper]).not_to have_received(:log_test_results_crash)
    end

    it 'logs the generic crash notice when no plugin names a cause' do
      run()
      expect(@collaborators[:generator_helper]).to have_received(:log_test_results_crash)
      expect(@collaborators[:generator_helper]).not_to have_received(:log_explained_crash)
    end

    it 'tells the plugins which explanation reaches the crash notice' do
      notices = []
      allow(@collaborators[:configurator]).to receive(:project_config_hash).and_return( { project_use_backtrace: :none } )
      allow(@plugin_manager).to receive(:explain_test_crash) { |arg_hash| notices << arg_hash[:crash_notice] }
      @generator.generate_test_results(
        tool: :fixture, context: :test, test_name: 'test_a', test_filepath: 'test/test_a.c', executable: 'build/test_a.out', result: 'build/test_a.pass'
      )
      expect(notices).to eq( [true] )
    end

    it 'asks the plugins once for a crash without backtraces' do
      run( explanation: 'ASan heap-buffer-overflow at src/a.c:9' )
      expect(@plugin_manager).to have_received(:explain_test_crash).once
    end

    it 'fails a crashed test as a crash when no plugin names a cause' do
      run()
      expect(results).to have_received(:create_crash_failure).with( 'test_a.c', anything, [], message: 'Test executable crashed' )
    end

    it 'has each simple backtrace rerun explained by the plugins' do
      run( use_backtrace: :simple )
      expect(backtrace).to have_received(:do_simple).with( 'test_a.c', 'build/test_a.out', anything, [], context: :test, tool: :fixture, explain: kind_of(Proc) )
    end

    # A tool that runs the reruns itself can't run under gdb
    it 'falls back to simple backtraces, with a notice, for a fixture tool that runs its own reruns' do
      run( tool: { name: 'wrapper', backtrace_rerun: true }, use_backtrace: :gdb )

      expect(backtrace).to have_received(:do_simple)
      expect(backtrace).not_to have_received(:do_gdb)
      expect(@collaborators[:loginator]).to have_received(:log).with( /:use_backtrace .*:gdb.*:simple/, Verbosity::NORMAL )
    end
  end

  # Test fixtures crash independently, but the fallback is the same for all of them
  describe 'the :gdb fallback notice' do
    before(:each) do
      allow(@collaborators[:generator_helper]).to receive(:test_crash?).and_return( true )
      allow(@collaborators[:test_context_extractor]).to receive(:lookup_test_cases).and_return( [] )
      allow(@collaborators[:generator_test_results]).to receive(:filter_test_cases) { |cases| cases }
      allow(@collaborators[:configurator]).to receive(:project_config_hash).and_return( { project_use_backtrace: :gdb } )
      allow(@plugin_manager).to receive(:pre_test_fixture_execute)
      allow(@plugin_manager).to receive(:post_test_fixture_execute)
      allow(@plugin_manager).to receive(:explain_test_crash)
    end

    def crash(test)
      @generator.generate_test_results(
        tool: { name: 'wrapper', backtrace_rerun: true }, context: :sanitize, test_name: test, test_filepath: "test/#{test}.c",
        executable: "build/#{test}.out", result: "build/#{test}.pass"
      )
    end

    it 'is logged once for a build with several crashes, though each falls back' do
      crash( 'test_a' )
      crash( 'test_b' )

      expect(@collaborators[:generator_test_results_backtrace]).to have_received(:do_simple).twice
      expect(@collaborators[:loginator]).to have_received(:log).with( /:use_backtrace .*:gdb.*:simple/, Verbosity::NORMAL ).once
    end

    it 'tells the crash notice that :gdb can\'t be used' do
      crash( 'test_a' )
      expect(@collaborators[:generator_helper]).to have_received(:log_test_results_crash).with( 'build/test_a.out', anything, :simple, gdb_unavailable: true )
    end
  end

  # On macOS, startup can find gdb unable to attach and fall back to :simple backtraces
  describe 'crash advice after startup ruled out :gdb' do
    before(:each) do
      allow(@collaborators[:generator_helper]).to receive(:test_crash?).and_return( true )
      allow(@collaborators[:test_context_extractor]).to receive(:lookup_test_cases).and_return( [] )
      allow(@collaborators[:generator_test_results]).to receive(:filter_test_cases) { |cases| cases }
      allow(@collaborators[:configurator]).to receive(:project_config_hash).and_return( { project_use_backtrace: :simple } )
      allow(@plugin_manager).to receive(:pre_test_fixture_execute)
      allow(@plugin_manager).to receive(:post_test_fixture_execute)
      allow(@plugin_manager).to receive(:explain_test_crash)
    end

    def crash(state)
      allow(@collaborators[:configurator]).to receive(:gdb_backtrace_state).and_return( state )
      @generator.generate_test_results(
        tool: :fixture, context: :test, test_name: 'test_a', test_filepath: 'test/test_a.c', executable: 'build/test_a.out', result: 'build/test_a.pass'
      )
    end

    it 'tells the crash notice that :gdb can\'t be used' do
      crash( :fell_back )
      expect(@collaborators[:generator_helper]).to have_received(:log_test_results_crash).with( 'build/test_a.out', anything, :simple, gdb_unavailable: true )
    end

    it 'leaves the advice to the crash notice when startup never asked about gdb' do
      crash( :unknown )
      expect(@collaborators[:generator_helper]).to have_received(:log_test_results_crash).with( 'build/test_a.out', anything, :simple, gdb_unavailable: false )
    end
  end

  describe '#generate_mock' do
    def generate(**extra)
      @generator.generate_mock(
        context: :test, mock: :mock_config, test: 'test_both', input_filepath: 'src/drivers/uart/config.h',
        output_path: 'build/test/mocks/test_both/drivers/uart', **extra
      )
    end

    it 'has CMock write straight into the mock\'s directory without a folder' do
      generate()

      expect(@generator_mocks).to have_received(:build_configuration).with( 'build/test/mocks/test_both/drivers/uart', overrides: {} )
      expect(@cmock).to have_received(:setup_mocks).with( 'src/drivers/uart/config.h', nil )
    end

    # CMock writes below its root at the folder, so the root is the directory less the folder
    it 'roots CMock above the folder and hands it the folder, which names the mock' do
      generate( folder: 'drivers/uart' )

      expect(@generator_mocks).to have_received(:build_configuration).with( 'build/test/mocks/test_both', overrides: {} )
      expect(@cmock).to have_received(:setup_mocks).with( 'src/drivers/uart/config.h', 'drivers/uart' )
    end

    it 'still reports the mock\'s own directory to plugins' do
      generate( folder: 'drivers/uart' )

      expect(@plugin_manager).to have_received(:pre_mock_generate).with( hash_including( output_path: 'build/test/mocks/test_both/drivers/uart' ) )
    end
  end
  # Windows' Installer Detection would otherwise demand administrator rights for some names
  describe '#generate_test_executable_manifest' do
    let(:file_wrapper) { @collaborators[:file_wrapper] }
    let(:loginator)    { @collaborators[:loginator] }

    def generate(test_filepath: 'test/test_a.c', windows: true, existing: nil)
      allow(@collaborators[:system_wrapper]).to receive(:windows?).and_return( windows )
      allow(file_wrapper).to receive(:exist?).and_return( !existing.nil? )
      allow(file_wrapper).to receive(:read).and_return( existing )
      allow(file_wrapper).to receive(:write)
      allow(loginator).to receive(:log)
      @generator.generate_test_executable_manifest( executable: 'build/test_a.exe', test_filepath: test_filepath )
    end

    it 'writes the manifest beside the executable on Windows' do
      generate()
      expect(file_wrapper).to have_received(:write).with( 'build/test_a.exe.manifest', TEST_EXECUTABLE_MANIFEST )
    end

    it 'writes nothing elsewhere' do
      generate( windows: false )
      expect(file_wrapper).not_to have_received(:write)
    end

    it 'leaves an identical manifest alone' do
      generate( existing: TEST_EXECUTABLE_MANIFEST )
      expect(file_wrapper).not_to have_received(:write)
    end

    it 'replaces a manifest that differs' do
      generate( existing: '<assembly/>' )
      expect(file_wrapper).to have_received(:write).with( 'build/test_a.exe.manifest', TEST_EXECUTABLE_MANIFEST )
    end

    it 'notes a test filename Windows recognizes as an installer' do
      generate( test_filepath: 'test/test_SetUp_parser.c' )
      expect(loginator).to have_received(:log).with(
        'Test filename `test_SetUp_parser.c` includes a keyword Windows recognizes as an installer (install, setup, update, patch) ' \
        'when built as a test executable. As a defensive measure, Ceedling generated a manifest beside the test executable to run without ' \
        'administrator privileges. Your toolchain may already embed a manifest that does the same.',
        Verbosity::COMPLAIN
      )
    end

    it 'notes nothing for an ordinary test filename' do
      generate()
      expect(loginator).not_to have_received(:log).with( anything, Verbosity::COMPLAIN )
    end

    it 'notes nothing off Windows' do
      generate( test_filepath: 'test/test_patch.c', windows: false )
      expect(loginator).not_to have_received(:log)
    end
  end
end
