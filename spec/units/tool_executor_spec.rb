# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/tool_executor'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'

# Scoped narrowly to the inline Ruby string expansion (--ruby-replacement) behavior
# introduced by RubyExpandinator. Broader ToolExecutor coverage is a pre-existing gap
# outside this feature's scope.
describe ToolExecutor do
  before(:each) do
    @configurator = double('configurator').as_null_object
    @tool_executor_helper = double('tool_executor_helper').as_null_object
    allow(@tool_executor_helper).to receive(:osify_path_separators) {|s| s}
    @loginator = double('loginator').as_null_object
    @verbosinator = double('verbosinator').as_null_object
    @system_wrapper = double('system_wrapper').as_null_object
    @ruby_expandinator = RubyExpandinator.new

    @tool_executor = described_class.new(
      {
        :configurator => @configurator,
        :tool_executor_helper => @tool_executor_helper,
        :loginator => @loginator,
        :verbosinator => @verbosinator,
        :system_wrapper => @system_wrapper,
        :ruby_expandinator => @ruby_expandinator
      }
    )
  end

  describe '#build_command_line — :executable expansion' do
    it 'raises CeedlingException when :executable contains a Ruby replacement pattern and the feature is disabled' do
      tool_config = { :name => 'my_tool', :executable => '#{1+1}' }

      expect {
        @tool_executor.build_command_line( tool_config, [] )
      }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'expands :executable when the feature is enabled' do
      @ruby_expandinator.enable!
      tool_config = { :name => 'my_tool', :executable => '#{1+1}' }

      command = @tool_executor.build_command_line( tool_config, [] )

      expect(command[:executable]).to eq('2')
    end
  end

  describe '#build_command_line — hash-style :arguments expansion' do
    it 'raises CeedlingException when an argument hash value contains a Ruby replacement pattern and the feature is disabled' do
      tool_config = {
        :name => 'my_tool',
        :executable => 'compiler',
        :arguments => [ { '--flag=$' => '#{1+1}' } ]
      }

      expect {
        @tool_executor.build_command_line( tool_config, [] )
      }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'expands an argument hash value when the feature is enabled' do
      @ruby_expandinator.enable!
      tool_config = {
        :name => 'my_tool',
        :executable => 'compiler',
        :arguments => [ { '--flag=$' => '#{1+1}' } ]
      }

      command = @tool_executor.build_command_line( tool_config, [] )

      expect(command[:line]).to include('--flag=2')
    end
  end
end
