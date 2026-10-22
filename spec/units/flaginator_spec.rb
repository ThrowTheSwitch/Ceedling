# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/flaginator'

# ConfigMatchinator's own matching/no-match-default semantics are already
# thoroughly pinned in config_matchinator_spec.rb, so @config_matchinator is
# stubbed wholesale here -- these specs only need to confirm Flaginator
# calls it correctly and handles each return shape correctly, not
# re-verify its internal matching logic.
describe Flaginator do
  before(:each) do
    @configurator       = double('configurator')
    @loginator          = double('loginator')
    @config_matchinator = double('config_matchinator')

    @flaginator = described_class.new({
      :configurator       => @configurator,
      :loginator          => @loginator,
      :config_matchinator => @config_matchinator,
    })
  end

  describe '#flags_defined?' do
    it 'delegates to config_matchinator with the :flags section, context, and a nil operation by default' do
      allow(@config_matchinator).to receive(:config_include?)
        .with(primary: :flags, secondary: :test, tertiary: nil)
        .and_return(true)

      expect(@flaginator.flags_defined?(context: :test)).to eq(true)
    end

    it 'passes a given operation through as the tertiary key' do
      allow(@config_matchinator).to receive(:config_include?)
        .with(primary: :flags, secondary: :test, tertiary: :compile)
        .and_return(false)

      expect(@flaginator.flags_defined?(context: :test, operation: :compile)).to eq(false)
    end
  end

  describe '#flag_down' do
    it 'returns the empty-array default when get_config finds no matching configuration' do
      allow(@config_matchinator).to receive(:get_config).and_return(nil)

      expect(@flaginator.flag_down(context: :test, operation: :compile)).to eq([])
    end

    it 'returns a caller-provided default when get_config finds no matching configuration' do
      allow(@config_matchinator).to receive(:get_config).and_return(nil)

      result = @flaginator.flag_down(context: :test, operation: :compile, default: ['-fallback'])

      expect(result).to eq(['-fallback'])
    end

    it 'flattens an Array result, handling nested arrays left over from YAML list aliasing' do
      allow(@config_matchinator).to receive(:get_config).and_return(['-foo', ['-bar', '-baz']])

      result = @flaginator.flag_down(context: :test, operation: :compile)

      expect(result).to eq(['-foo', '-bar', '-baz'])
    end

    it 'delegates a Hash result to config_matchinator#matches? with the correct argument shape' do
      hash_config = { '*' => ['-foo'] }
      allow(@config_matchinator).to receive(:get_config).and_return(hash_config)
      allow(@config_matchinator).to receive(:matches?)
        .with(
          hash: hash_config,
          filepath: 'test_Foo.c',
          section: :flags,
          context: :test,
          operation: :compile,
          no_match_default: nil
        )
        .and_return(['-matched'])

      result = @flaginator.flag_down(context: :test, operation: :compile, filepath: 'test_Foo.c')

      expect(result).to eq(['-matched'])
    end

    it 'threads no_match_default through to config_matchinator#matches? unchanged' do
      hash_config = { 'Model' => ['-foo'] }
      allow(@config_matchinator).to receive(:get_config).and_return(hash_config)
      allow(@config_matchinator).to receive(:matches?)
        .with(
          hash: hash_config,
          filepath: 'test_Foo.c',
          section: :flags,
          context: :test,
          operation: :compile,
          no_match_default: ['-fallback']
        )
        .and_return(['-fallback'])

      result = @flaginator.flag_down(context: :test, operation: :compile, filepath: 'test_Foo.c', no_match_default: ['-fallback'])

      expect(result).to eq(['-fallback'])
    end

    it 'returns an empty array for a config value of an unexpected type' do
      allow(@config_matchinator).to receive(:get_config).and_return('not-an-array-or-hash')

      expect(@flaginator.flag_down(context: :test, operation: :compile)).to eq([])
    end
  end
end
