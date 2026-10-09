# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator'
require 'ceedling/constants'

# Scoped to Generator#generate_object_file_c's choice of which file the compiler receives.
describe Generator do
  before(:each) do
    @tool_executor  = double('tool_executor')
    @plugin_manager = double('plugin_manager')

    allow(@tool_executor).to receive(:build_command_line).and_return( { line: 'gcc', options: {} } )
    allow(@tool_executor).to receive(:exec).and_return( { output: '', exit_code: 0 } )
    allow(@plugin_manager).to receive(:pre_compile_execute)
    allow(@plugin_manager).to receive(:post_compile_execute)

    collaborators = [
      :configurator, :generator_helper, :generator_mocks, :generator_test_results,
      :generator_test_results_backtrace, :generator_partials, :test_context_extractor,
      :file_finder, :file_path_utils, :reportinator, :loginator, :test_runner_manager
    ].to_h { |name| [name, double( name.to_s ).as_null_object] }

    @generator = described_class.new(
      collaborators.merge( tool_executor: @tool_executor, plugin_manager: @plugin_manager )
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
end
