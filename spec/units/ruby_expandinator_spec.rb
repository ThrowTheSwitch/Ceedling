# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'

describe RubyExpandinator do
  before(:each) do
    @ruby_expandinator = described_class.new
  end

  describe '#expand' do
    # Baseline: the vast majority of config strings have no `#{...}` at all, and this
    # must be a true no-op -- value passed through untouched, regardless of enabled state.
    it 'returns a string unchanged when it contains no Ruby replacement pattern' do
      expect(@ruby_expandinator.expand('plain string', source: 'x')).to eq('plain string')
    end

    # Core security behavior: the whole point of this class. Disabled is the default
    # state, so this is the "secure by default" case -- must raise, must name `source`.
    it 'raises CeedlingException when the pattern is present and the feature is disabled' do
      expect {
        @ruby_expandinator.expand('#{1+1}', source: ':defines')
      }.to raise_error(CeedlingException, /:defines/)
    end

    # Once explicitly opted into, expansion must actually work -- confirms the eval
    # wiring itself (Object.module_eval), not just the gate.
    it 'evaluates and returns the expanded result when the pattern is present and the feature is enabled' do
      @ruby_expandinator.enable!
      expect(@ruby_expandinator.expand('#{1+1}', source: 'x')).to eq('2')
    end
  end

  describe '#check!' do
    # Mirrors #expand's disabled case but for the fail-fast predicate used by
    # tool_validator.rb -- same gate logic, but must never evaluate the string.
    it 'raises CeedlingException when the pattern is present and the feature is disabled' do
      expect {
        @ruby_expandinator.check!('#{1+1}', source: 'tool \'x\' :executable')
      }.to raise_error(CeedlingException, /tool 'x' :executable/)
    end

    it 'does not raise when the pattern is absent, regardless of enabled state' do
      expect { @ruby_expandinator.check!('plain string', source: 'x') }.not_to raise_error
    end

    # #check! must be a true no-op on the happy path -- confirms it never accidentally
    # evaluates the string even when enabled (its only job is gating, not expanding).
    it 'does not evaluate the string even when the feature is enabled' do
      @ruby_expandinator.enable!
      # If check! evaluated this, invalid Ruby syntax would raise a SyntaxError/NameError
      # instead of silently passing.
      expect { @ruby_expandinator.check!('#{this is not valid ruby}', source: 'x') }.not_to raise_error
    end
  end

  describe '#replacement?' do
    it 'returns true when the string contains the Ruby replacement pattern' do
      expect(@ruby_expandinator.replacement?('#{ENV["HOME"]}')).to eq(true)
    end

    it 'returns false when the string does not contain the Ruby replacement pattern' do
      expect(@ruby_expandinator.replacement?('plain string')).to eq(false)
    end
  end

  describe '#enable! / #enabled?' do
    it 'defaults to disabled' do
      expect(@ruby_expandinator.enabled?).to be_falsey
    end

    it 'is enabled after #enable!' do
      @ruby_expandinator.enable!
      expect(@ruby_expandinator.enabled?).to eq(true)
    end

    # State-machine sanity check: nothing in this codebase should ever be able to turn
    # the feature back off mid-process once a user has opted in via the CLI flag.
    it '#enable! is idempotent and there is no way to disable once enabled' do
      @ruby_expandinator.enable!
      @ruby_expandinator.enable!
      expect(@ruby_expandinator.enabled?).to eq(true)
    end
  end
end
