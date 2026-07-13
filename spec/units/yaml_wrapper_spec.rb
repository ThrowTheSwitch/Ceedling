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

    it 'round-trips a nested Hash with symbol keys, mirroring test-result usage' do
      structure = { source: { file: 'foo.c', dirname: '.', basename: 'foo.c' }, time: 0.006512 }
      dumped = YAML.dump(structure)

      expect(@yaml_wrapper.load_string(dumped)).to eq(structure)
    end

    # Test for protection against security vulnerabilities in YAML deserialization.
    it 'refuses to instantiate arbitrary Ruby objects and reports it as :unsafe' do
      yaml = "--- !ruby/object:OpenStruct {}\n"

      expect { @yaml_wrapper.load_string(yaml) }.to raise_error(YamlLoadException) do |e|
        expect(e.reason).to eq(:unsafe)
        expect(e.message).to match(/not permitted by safe YAML loading/i)
      end
    end

    it 'reports malformed YAML content as :syntax' do
      yaml = "a: [1, 2\n" # unterminated flow sequence

      expect { @yaml_wrapper.load_string(yaml) }.to raise_error(YamlLoadException) do |e|
        expect(e.reason).to eq(:syntax)
        expect(e.message).to match(/malformed yaml content/i)
      end
    end

    it 'embeds the source_label in the underlying Psych message' do
      yaml = "a: [1, 2\n"

      expect { @yaml_wrapper.load_string(yaml, source_label: 'my_project.yml') }.to raise_error(YamlLoadException) do |e|
        expect(e.message).to include('my_project.yml')
      end
    end
  end

  describe '#load' do
    it 'reports a missing file as :not_found' do
      expect { @yaml_wrapper.load('/no/such/file.yml') }.to raise_error(YamlLoadException) do |e|
        expect(e.reason).to eq(:not_found)
        expect(e.message).to match(/could not find yaml file/i)
      end
    end
  end

  # Test cacheing of Psych version probe that determines calling interface for safe_load.
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
