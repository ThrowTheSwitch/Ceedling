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

# Unit coverage for ConfiguratorValidator through a doubled file layer. What these
# validations make of a real project tree is proven in
# spec/integration/configurator_validation_spec.rb.
describe ConfiguratorValidator do
  include ConfigYamlHelper

  before(:each) do
    @file_wrapper   = double('file_wrapper')
    @loginator      = double('loginator', log: nil)
    @tool_validator = double('tool_validator')

    @validator = described_class.new(
      {
        config_walkinator: ConfigWalkinator.new,
        file_wrapper:      @file_wrapper,
        loginator:         @loginator,
        reportinator:      Reportinator.new,
        tool_validator:    @tool_validator
      }
    )
  end

  def existing(*paths)
    allow(@file_wrapper).to receive(:exist?) { |path| paths.include?( path ) }
  end

  def directories(*paths)
    allow(@file_wrapper).to receive(:directory?) { |path| paths.include?( path ) }
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

  describe '#validate_path_list' do
    let(:config) { config_from_yaml( ":paths:\n  :test:\n    - +:test/**\n    - -:test/ignore\n    - '**/generated'\n" ) }

    it 'checks each path stripped of its aggregation decorator and glob' do
      existing('test', 'test/ignore')
      expect(@validator.validate_path_list( config, :paths, :test )).to be true
    end

    it 'skips a path that begins with a glob' do
      existing('test', 'test/ignore')
      @validator.validate_path_list( config, :paths, :test )
      expect(@file_wrapper).to_not have_received(:exist?).with('')
    end

    it 'logs each path that does not exist' do
      existing('test')
      expect(@validator.validate_path_list( config, :paths, :test )).to be false
      expect(@loginator).to have_received(:log).with("Config path :paths ↳ :test => 'test/ignore' does not exist in the filesystem.", Verbosity::ERRORS)
    end

    it 'fails a missing entry' do
      expect(@validator.validate_path_list( config, :paths, :source )).to be false
    end
  end

  describe '#validate_paths_entries' do
    def validate(yaml_list)
      @validator.validate_paths_entries( config_from_yaml( ":paths:\n  :source:\n#{yaml_list}" ), :source )
    end

    it 'accepts a glob that yields directories' do
      existing; directories('src', 'src/a')
      allow(@file_wrapper).to receive(:directory_listing).with('src/**/**').and_return(['src', 'src/a', 'src/a/x.c'])

      expect(validate( "    - src/**\n" )).to be true
    end

    it 'warns about and skips a path naming a file' do
      existing('src/main.c'); directories

      expect(validate( "    - src/main.c\n" )).to be true
      expect(@loginator).to have_received(:log).with(/'src\/main.c' is a filepath and will be ignored/, Verbosity::COMPLAIN)
    end

    it 'accepts a subdirectory glob of a directory that has no subdirectories' do
      existing; directories
      allow(@file_wrapper).to receive(:directory_listing).and_return([])

      expect(validate( "    - src/*\n" )).to be true
    end

    it 'logs a path that yields no directories' do
      existing; directories
      allow(@file_wrapper).to receive(:directory_listing).and_return([])

      expect(validate( "    - -:src/missing\n" )).to be false
      expect(@loginator).to have_received(:log).with(/'src\/missing' yielded no directories/, Verbosity::ERRORS)
    end

    it 'escapes literal brackets before globbing' do
      existing; directories('src/[legacy]')
      allow(@file_wrapper).to receive(:directory_listing).with('src/\[legacy\]').and_return(['src/[legacy]'])

      expect(validate( "    - 'src/[legacy]'\n" )).to be true
    end

    it 'fails a missing entry' do
      expect(@validator.validate_paths_entries( { paths: {} }, :source )).to be false
    end
  end

  describe '#validate_files_entries' do
    def validate(yaml_list)
      @validator.validate_files_entries( config_from_yaml( ":files:\n  :source:\n#{yaml_list}" ), :source )
    end

    it 'accepts a glob that yields files' do
      existing; directories
      allow(@file_wrapper).to receive(:instantiate_file_list).with('src/*.c').and_return(['src/a.c'])

      expect(validate( "    - +:src/*.c\n" )).to be true
    end

    it 'warns about and skips a path naming a directory' do
      existing('src'); directories('src')

      expect(validate( "    - src\n" )).to be true
      expect(@loginator).to have_received(:log).with(/'src' is a directory path and will be ignored/, Verbosity::COMPLAIN)
    end

    it 'logs a glob that yields no files' do
      existing; directories
      allow(@file_wrapper).to receive(:instantiate_file_list).and_return([])

      expect(validate( "    - src/*.x\n" )).to be false
      expect(@loginator).to have_received(:log).with(/'src\/\*.x' yielded no files/, Verbosity::ERRORS)
    end

    it 'escapes literal brackets before globbing' do
      existing; directories
      allow(@file_wrapper).to receive(:instantiate_file_list).with('src/\[legacy\]/*.c').and_return(['src/[legacy]/a.c'])

      expect(validate( "    - 'src/[legacy]/*.c'\n" )).to be true
    end

    it 'fails a missing entry' do
      expect(@validator.validate_files_entries( { files: {} }, :source )).to be false
    end
  end

  describe '#validate_filepath_simple' do
    it 'accepts an existing path' do
      existing('helper.h')
      expect(@validator.validate_filepath_simple( 'helper.h', :cmock, :unity_helper_path )).to be true
    end

    it 'logs a missing path with the configuration walk it came from' do
      existing
      expect(@validator.validate_filepath_simple( 'helper.h', :cmock, :unity_helper_path )).to be false
      expect(@loginator).to have_received(:log).with("Config path 'helper.h' associated with :cmock ↳ :unity_helper_path does not exist in the filesystem.", Verbosity::ERRORS)
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
