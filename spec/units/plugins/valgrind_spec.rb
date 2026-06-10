# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake'
require 'ceedling/constants'
require 'ceedling/plugin'

# Define Ceedling runtime path constants needed by valgrind_constants.rb at
# require time. The `unless defined?` guard keeps them from being re-assigned
# if another spec already loaded them.
PROJECT_BUILD_ROOT = 'build' unless defined?(PROJECT_BUILD_ROOT)

$: << File.expand_path('../../../../plugins/valgrind/lib', __FILE__)

require 'valgrind_constants'
require 'valgrind'

# The END block at the bottom of valgrind.rb runs after RSpec finishes and
# accesses the top-level @ceedling variable. Set a minimal stub so it does
# not raise a NoMethodError and pollute the exit code.
_task_invoker_stub = Object.new
def _task_invoker_stub.invoked?(_); false; end
@ceedling = { task_invoker: _task_invoker_stub } unless defined?(@ceedling)

# ===========================================================================
describe "Valgrind constants" do
  it "defines VALGRIND_ROOT_NAME as 'valgrind'" do
    expect(VALGRIND_ROOT_NAME).to eq('valgrind')
  end

  it "defines VALGRIND_TASK_ROOT as 'valgrind:'" do
    expect(VALGRIND_TASK_ROOT).to eq('valgrind:')
  end

  it "defines VALGRIND_SYM as :valgrind" do
    expect(VALGRIND_SYM).to eq(:valgrind)
  end

  it "defines VALGRIND_BUILD_PATH under PROJECT_BUILD_ROOT/test" do
    expect(VALGRIND_BUILD_PATH).to eq(File.join('build', 'test'))
  end

  it "defines VALGRIND_BUILD_OUTPUT_PATH under VALGRIND_BUILD_PATH/out" do
    expect(VALGRIND_BUILD_OUTPUT_PATH).to eq(File.join('build', 'test', 'out'))
  end
end

# ===========================================================================
describe Valgrind do
  # -------------------------------------------------------------------------
  describe '#setup' do
    subject(:valgrind) do
      instance = Valgrind.allocate
      instance.setup
      instance
    end

    it 'initializes result_list as an empty array' do
      expect(valgrind.instance_variable_get(:@result_list)).to eq([])
    end

    it 'exposes config via attr_reader' do
      expect(valgrind.config).to be_a(Hash)
    end

    it 'sets config[:project_test_build_output_path] to VALGRIND_BUILD_OUTPUT_PATH' do
      expect(valgrind.config[:project_test_build_output_path]).to eq(VALGRIND_BUILD_OUTPUT_PATH)
    end

    it 'sets plugin_root to the valgrind plugin directory' do
      plugin_root = valgrind.instance_variable_get(:@plugin_root)
      expect(plugin_root).to end_with(File.join('plugins', 'valgrind'))
    end
  end
end
