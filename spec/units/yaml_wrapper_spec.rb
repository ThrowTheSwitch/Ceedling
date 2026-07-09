# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/yaml_wrapper'

describe YamlWrapper do
  before(:each) do
    @yaml_wrapper = described_class.new
  end

  describe '#load_string' do
    it 'deserializes colon-prefixed keys as symbols and other keys as strings' do
      yaml = <<~YAML
        :foo: 1
        bar: 2
      YAML

      expect(@yaml_wrapper.load_string(yaml)).to eq({ foo: 1, "bar" => 2 })
    end

    it 'resolves YAML aliases' do
      yaml = <<~YAML
        defaults: &defaults
          :timeout: 30
        production:
          <<: *defaults
          :timeout: 60
      YAML

      result = @yaml_wrapper.load_string(yaml)

      expect(result["production"][:timeout]).to eq(60)
      expect(result["defaults"][:timeout]).to eq(30)
    end

    it 'round-trips a nested Hash with symbol keys, mirroring cache and test-result usage' do
      structure = { source: { file: 'foo.c', dirname: '.', basename: 'foo.c' }, time: 0.006512 }
      dumped = YAML.dump(structure)

      expect(@yaml_wrapper.load_string(dumped)).to eq(structure)
    end

    it 'refuses to instantiate arbitrary Ruby objects' do
      yaml = "--- !ruby/object:OpenStruct {}\n"

      expect { @yaml_wrapper.load_string(yaml) }.to raise_error(Psych::Exception)
    end
  end

  describe '.psych_safe_load_uses_keywords?' do
    def reset_memoized_psych_check
      if described_class.instance_variable_defined?(:@psych_safe_load_uses_keywords)
        described_class.send(:remove_instance_variable, :@psych_safe_load_uses_keywords)
      end
    end

    before(:each) { reset_memoized_psych_check }
    after(:each)  { reset_memoized_psych_check }

    it 'selects the keyword calling convention for Psych >= 4.0' do
      stub_const('Psych::VERSION', '4.0.0')

      expect(described_class.psych_safe_load_uses_keywords?).to eq(true)
    end

    it 'selects the positional calling convention for Psych < 4.0' do
      stub_const('Psych::VERSION', '3.3.2')

      expect(described_class.psych_safe_load_uses_keywords?).to eq(false)
    end
  end
end
