# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/defineinator'

# ConfigMatchinator's own matching/no-match-default semantics are already
# thoroughly pinned in config_matchinator_spec.rb, so @config_matchinator is
# stubbed wholesale here -- these specs only need to confirm Defineinator
# calls it correctly and handles each return shape correctly, not
# re-verify its internal matching logic.
describe Defineinator do
  before(:each) do
    @configurator       = double('configurator')
    @loginator          = double('loginator')
    @config_matchinator = double('config_matchinator')

    @defineinator = described_class.new({
      :configurator       => @configurator,
      :loginator          => @loginator,
      :config_matchinator => @config_matchinator,
    })
  end

  describe '#defines_defined?' do
    it 'delegates to config_matchinator with the :defines top key and the given context' do
      allow(@config_matchinator).to receive(:config_include?)
        .with(primary: :defines, secondary: :test)
        .and_return(true)

      expect(@defineinator.defines_defined?(context: :test)).to eq(true)
    end

    it 'passes through a false result unchanged' do
      allow(@config_matchinator).to receive(:config_include?)
        .with(primary: :defines, secondary: :release)
        .and_return(false)

      expect(@defineinator.defines_defined?(context: :release)).to eq(false)
    end
  end

  describe '#defines' do
    it 'returns the empty-array default when get_config finds no matching configuration' do
      allow(@config_matchinator).to receive(:get_config).and_return(nil)

      expect(@defineinator.defines(subkey: :test)).to eq([])
    end

    it 'returns a caller-provided default when get_config finds no matching configuration' do
      allow(@config_matchinator).to receive(:get_config).and_return(nil)

      expect(@defineinator.defines(subkey: :test, default: [:FALLBACK])).to eq([:FALLBACK])
    end

    it 'flattens an Array result, handling nested arrays left over from YAML list aliasing' do
      allow(@config_matchinator).to receive(:get_config).and_return([:A, [:B, :C]])

      expect(@defineinator.defines(subkey: :test)).to eq([:A, :B, :C])
    end

    it 'delegates a Hash result to config_matchinator#matches? with the correct argument shape' do
      hash_config = { '*' => [:A] }
      allow(@config_matchinator).to receive(:get_config).and_return(hash_config)
      allow(@config_matchinator).to receive(:matches?)
        .with(
          hash: hash_config,
          filepath: 'test_Foo.c',
          section: :defines,
          context: :test,
          no_match_default: nil
        )
        .and_return([:MATCHED])

      result = @defineinator.defines(subkey: :test, filepath: 'test_Foo.c')

      expect(result).to eq([:MATCHED])
    end

    it 'threads no_match_default through to config_matchinator#matches? unchanged' do
      hash_config = { 'Model' => [:A] }
      allow(@config_matchinator).to receive(:get_config).and_return(hash_config)
      allow(@config_matchinator).to receive(:matches?)
        .with(hash: hash_config, filepath: 'test_Foo.c', section: :defines, context: :test, no_match_default: [:FALLBACK])
        .and_return([:FALLBACK])

      result = @defineinator.defines(subkey: :test, filepath: 'test_Foo.c', no_match_default: [:FALLBACK])

      expect(result).to eq([:FALLBACK])
    end

    it 'returns an empty array for a config value of an unexpected type' do
      allow(@config_matchinator).to receive(:get_config).and_return('not-an-array-or-hash')

      expect(@defineinator.defines(subkey: :test)).to eq([])
    end

    it 'uses an explicit topkey override instead of the default :defines section' do
      allow(@config_matchinator).to receive(:get_config)
        .with(primary: :unity, secondary: :defines)
        .and_return([:UNITY_INCLUDE_PRINT_FORMATTED])

      result = @defineinator.defines(topkey: :unity, subkey: :defines)

      expect(result).to eq([:UNITY_INCLUDE_PRINT_FORMATTED])
    end
  end

  describe '#generate_test_definition' do
    it 'returns an empty array when :defines ↳ :use_test_definition is disabled' do
      allow(@configurator).to receive(:defines_use_test_definition).and_return(false)

      expect(@defineinator.generate_test_definition(filepath: 'test/test_Foo.c')).to eq([])
    end

    it 'derives an uppercase, underscore-wrapped symbol from the test file basename' do
      allow(@configurator).to receive(:defines_use_test_definition).and_return(true)

      result = @defineinator.generate_test_definition(filepath: 'test/test_Foo.c')

      expect(result).to eq(['_TEST_FOO_'])
    end

    it 'replaces non-ASCII bytes with underscores but preserves dashes, matching the documented example' do
      allow(@configurator).to receive(:defines_use_test_definition).and_return(true)

      # Matches docs/mkdocs/configuration/reference/defines.md's own worked example
      # verbatim: "Underscores and dashes are preserved."
      result = @defineinator.generate_test_definition(filepath: 'test_123abc-xyz😵.c')

      expect(result).to eq(['_TEST_123ABC-XYZ_'])
    end

    it 'does not double up a leading or trailing underscore already present in the basename' do
      allow(@configurator).to receive(:defines_use_test_definition).and_return(true)

      result = @defineinator.generate_test_definition(filepath: '_test_Foo_.c')

      expect(result).to eq(['_TEST_FOO_'])
    end

    it 'treats a leading-dot-only filepath as having no extension to strip, per File.basename' do
      allow(@configurator).to receive(:defines_use_test_definition).and_return(true)

      # File.basename('.c', '.*') returns '.c' unchanged -- a leading dot with nothing
      # before it is a dotfile name, not a stem+extension, so '.*' has nothing to strip.
      # The leading '.' then falls to the non-alphanumeric gsub same as any other
      # punctuation, and the already-underscore-prefixed result isn't prepended again.
      result = @defineinator.generate_test_definition(filepath: '.c')

      expect(result).to eq(['_C_'])
    end
  end
end
