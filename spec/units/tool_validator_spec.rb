# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/tool_validator'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'

# Scoped narrowly to the inline Ruby string expansion (--ruby-replacement) fail-fast
# gating behavior introduced by RubyExpandinator. Broader ToolValidator coverage is a
# pre-existing gap outside this feature's scope.
describe ToolValidator do
  before(:each) do
    @file_wrapper = double('file_wrapper').as_null_object
    @loginator = double('loginator').as_null_object
    @system_wrapper = double('system_wrapper').as_null_object
    @reportinator = double('reportinator').as_null_object
    @ruby_expandinator = RubyExpandinator.new

    @tool_validator = described_class.new(
      {
        :file_wrapper => @file_wrapper,
        :loginator => @loginator,
        :system_wrapper => @system_wrapper,
        :reportinator => @reportinator,
        :ruby_expandinator => @ruby_expandinator
      }
    )
  end

  describe '#validate — Ruby replacement pattern in :executable' do
    let(:tool) { { :name => 'my_tool', :executable => '#{1+1}' } }

    it 'raises CeedlingException (fail-fast, not deferred) when the feature is disabled and boom is true' do
      expect {
        @tool_validator.validate( tool: tool, extension: '.exe', boom: true )
      }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'logs and returns false when the feature is disabled and boom is false' do
      expect(@loginator).to receive(:log).with(/my_tool/, anything)

      expect(@tool_validator.validate( tool: tool, extension: '.exe', boom: false )).to eq(false)
    end

    it 'passes validation (deferring to shell at run time) when the feature is enabled' do
      @ruby_expandinator.enable!

      # Assert no exception (the fail-fast gate this spec targets doesn't trigger) --
      # not asserting the aggregate `valid` boolean, since validate() also folds in
      # validate_stderr_redirect()'s result, which is outside this spec's scope.
      expect { @tool_validator.validate( tool: tool, extension: '.exe', boom: true ) }.not_to raise_error
    end
  end
end
