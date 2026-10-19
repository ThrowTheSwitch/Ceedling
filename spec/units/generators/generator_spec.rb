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
      :file_finder, :file_path_utils, :reportinator, :loginator, :test_runner_manager
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

    def run(tool: :fixture, use_backtrace: :none, explanation: nil)
      allow(@collaborators[:configurator]).to receive(:project_config_hash).and_return( { project_use_backtrace: use_backtrace } )
      allow(@plugin_manager).to receive(:explain_test_crash) { |arg_hash| arg_hash[:explanation] = explanation }

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
end
