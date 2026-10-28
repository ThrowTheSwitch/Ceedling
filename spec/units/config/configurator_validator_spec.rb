# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'config_yaml_helper'
require 'ceedling/config/configurator_validator'
require 'ceedling/config/config_walkinator'
require 'ceedling/reportinator'

# Unit coverage for ConfiguratorValidator's checks of required entries, tools, and matchers
describe ConfiguratorValidator do
  include ConfigYamlHelper

  before(:each) do
    @loginator      = double('loginator', log: nil)
    @tool_validator = double('tool_validator')

    @validator = described_class.new(
      {
        config_walkinator: ConfigWalkinator.new,
        loginator:         @loginator,
        reportinator:      Reportinator.new,
        tool_validator:    @tool_validator
      }
    )
  end

  describe '#exists?' do
    let(:config) { config_from_yaml( ":project:\n  :build_root: build\n  :use_mocks: false\n" ) }

    it 'finds a value at the end of a key walk' do
      expect(@validator.exists?( config, :project, :build_root )).to be true
    end

    it 'counts a false value as present' do
      expect(@validator.exists?( config, :project, :use_mocks )).to be true
    end

    it 'logs the full walk of a missing entry' do
      expect(@validator.exists?( config, :paths, :test )).to be false
      expect(@loginator).to have_received(:log).with('Required config file entry :paths ↳ :test does not exist.', Verbosity::ERRORS)
    end
  end

  describe '#validate_tool' do
    let(:config) { { tools: { test_compiler: { executable: 'gcc' } }, extension: { executable: '.out' } } }

    it 'hands the tool, its walk, and the executable extension to the tool validator' do
      expect(@tool_validator).to receive(:validate).with(
        tool: { executable: 'gcc' }, name: ':tools ↳ :test_compiler', extension: '.out', respect_optional: true
      ).and_return(true)

      expect(@validator.validate_tool( config: config, key: :test_compiler )).to be true
    end

    it 'passes through a request to ignore the optional flag' do
      expect(@tool_validator).to receive(:validate).with(hash_including( respect_optional: false )).and_return(false)

      expect(@validator.validate_tool( config: config, key: :test_compiler, respect_optional: false )).to be false
    end
  end

  describe '#validate_matcher' do
    it 'accepts a well-formed regular expression' do
      expect { @validator.validate_matcher( '/Test(Foo|Bar)/' ) }.to_not raise_error
    end

    it 'rejects a malformed regular expression' do
      expect { @validator.validate_matcher( '/Test(/' ) }.to raise_error(RuntimeError, /invalid regular expression/)
    end

    it 'accepts a substring or wildcard of letters, digits, spaces, slashes, dots, dashes, underscores, and asterisks' do
      expect { @validator.validate_matcher( 'test/Test_Foo-1 *.c' ) }.to_not raise_error
    end

    it 'treats a path with inner slashes as a substring, not a regular expression' do
      expect { @validator.validate_matcher( 'test/Foo+Bar/' ) }.to raise_error(RuntimeError, /'\+'/)
    end

    it 'names each distinct invalid character once' do
      expect { @validator.validate_matcher( 'Foo$Bar$#' ) }.to raise_error(RuntimeError, /'\$', '#'\z/)
    end
  end
end
