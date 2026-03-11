
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partials'
require 'ostruct'

describe PartializerHelper do
  before(:each) do
    @partializer_utils = double( "PartializerUtils" )
    @partializer_parser = double( "PartializerParser" )
    @file_finder = double( "FileFinder" )

    @helper = described_class.new(
      {
        :partializer_utils => @partializer_utils,
        :partializer_parser => @partializer_parser,
        :file_finder => @file_finder
      }
    )
  end

  context "#manufacture_partial_configs" do
    it "returns empty hash when test_context_configs is empty" do
      test_context_configs = []
      
      result = @helper.manufacture_partial_configs(test_context_configs)
      
      expect(result).to eq({})
    end

    it "creates config for single module" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' }
      ]
      
      result = @helper.manufacture_partial_configs(test_context_configs)
      
      expect(result).to have_key('module1')
      expect(result['module1'].module).to eq('module1')
      expect(result.size).to eq(1)
    end

    it "creates configs for multiple different modules" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module2' },
        { Partials::TEST_PRIVATE => 'module3' }
      ]
      
      result = @helper.manufacture_partial_configs(test_context_configs)
      
      expect(result).to have_key('module1')
      expect(result).to have_key('module2')
      expect(result).to have_key('module3')
      expect(result['module1'].module).to eq('module1')
      expect(result['module2'].module).to eq('module2')
      expect(result['module3'].module).to eq('module3')
      expect(result.size).to eq(3)
    end

    it "creates single config when same module appears multiple times" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module1' },
        { Partials::TEST_PRIVATE => 'module1' }
      ]
      
      result = @helper.manufacture_partial_configs(test_context_configs)
      
      expect(result).to have_key('module1')
      expect(result['module1'].module).to eq('module1')
      expect(result.size).to eq(1)
    end
  end

  context "#config_collect_partial_types" do
    it "does nothing when test_context_configs is empty" do
      test_context_configs = []
      configs = {}
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs).to eq({})
    end

    it "adds TEST_PUBLIC type to config" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to eq([Partials::TEST_PUBLIC])
    end

    it "adds TEST_PRIVATE and TEST_PUBLIC types when TEST_PRIVATE is specified" do
      test_context_configs = [
        { Partials::TEST_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PRIVATE, Partials::TEST_PUBLIC)
    end

    it "adds MOCK_PUBLIC type to config" do
      test_context_configs = [
        { Partials::MOCK_PUBLIC => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to eq([Partials::MOCK_PUBLIC])
    end

    it "adds MOCK_PRIVATE type to config" do
      test_context_configs = [
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to eq([Partials::MOCK_PRIVATE])
    end

    it "collects multiple types for same module" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE)
    end

    it "collects types for multiple modules" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module2' },
        { Partials::TEST_PRIVATE => 'module3' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: []),
        'module2' => OpenStruct.new(module: 'module2', types: []),
        'module3' => OpenStruct.new(module: 'module3', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to eq([Partials::TEST_PUBLIC])
      expect(configs['module2'].types).to eq([Partials::MOCK_PRIVATE])
      expect(configs['module3'].types).to contain_exactly(Partials::TEST_PRIVATE, Partials::TEST_PUBLIC)
    end

    it "removes duplicate types from config" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE)
      expect(configs['module1'].types.count(Partials::TEST_PUBLIC)).to eq(1)
    end

    it "removes duplicate TEST_PUBLIC when TEST_PRIVATE adds it" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::TEST_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PUBLIC, Partials::TEST_PRIVATE)
      expect(configs['module1'].types.count(Partials::TEST_PUBLIC)).to eq(1)
    end

    it "handles all four partial types for same module" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::TEST_PRIVATE => 'module1' },
        { Partials::MOCK_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(
        Partials::TEST_PUBLIC,
        Partials::TEST_PRIVATE,
        Partials::MOCK_PUBLIC,
        Partials::MOCK_PRIVATE
      )
    end

    it "handles complex scenario with multiple modules and duplicate types" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module2' },
        { Partials::TEST_PRIVATE => 'module1' },
        { Partials::MOCK_PUBLIC => 'module3' },
        { Partials::TEST_PUBLIC => 'module2' },
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: []),
        'module2' => OpenStruct.new(module: 'module2', types: []),
        'module3' => OpenStruct.new(module: 'module3', types: [])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(
        Partials::TEST_PUBLIC,
        Partials::TEST_PRIVATE,
        Partials::MOCK_PRIVATE
      )
      expect(configs['module2'].types).to contain_exactly(
        Partials::MOCK_PRIVATE,
        Partials::TEST_PUBLIC
      )
      expect(configs['module3'].types).to eq([Partials::MOCK_PUBLIC])
    end

    it "preserves existing types in config when adding new ones" do
      test_context_configs = [
        { Partials::MOCK_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PUBLIC])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE)
    end

    it "handles TEST_PRIVATE when TEST_PUBLIC already exists" do
      test_context_configs = [
        { Partials::TEST_PRIVATE => 'module1' }
      ]
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PUBLIC])
      }
      
      @helper.config_collect_partial_types(test_context_configs, configs)
      
      expect(configs['module1'].types).to contain_exactly(Partials::TEST_PUBLIC, Partials::TEST_PRIVATE)
      expect(configs['module1'].types.count(Partials::TEST_PUBLIC)).to eq(1)
    end
  end

  context "#validate_partial_configs" do
    it "does not raise error when configs is empty" do
      configs = {}
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "does not raise error for valid TEST_PUBLIC config" do
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PUBLIC])
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "does not raise error for valid TEST_PRIVATE config" do
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PRIVATE])
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "does not raise error for valid MOCK_PUBLIC config" do
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::MOCK_PUBLIC])
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "does not raise error for valid MOCK_PRIVATE config" do
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::MOCK_PRIVATE])
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "raises error when TEST_PUBLIC and MOCK_PUBLIC both present" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC, Partials::MOCK_PUBLIC]
        )
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.to raise_error(CeedlingException, /cannot both test and mock public functions/)
    end

    it "raises error when TEST_PRIVATE and MOCK_PRIVATE both present" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PRIVATE, Partials::MOCK_PRIVATE]
        )
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.to raise_error(CeedlingException, /cannot both test and mock private functions/)
    end

    it "does not raise error for TEST_PUBLIC and MOCK_PRIVATE combination" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE]
        )
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "does not raise error for TEST_PRIVATE and MOCK_PUBLIC combination" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PRIVATE, Partials::MOCK_PUBLIC]
        )
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end

    it "validates multiple modules independently" do
      configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PUBLIC]),
        'module2' => OpenStruct.new(module: 'module2', types: [Partials::MOCK_PRIVATE])
      }
      
      expect {
        @helper.validate_partial_configs(configs)
      }.not_to raise_error
    end
  end

  context "#config_populate_filepaths" do
    it "does nothing when configs is empty" do
      configs = {}
      
      @helper.config_populate_filepaths(configs)
      
      expect(configs).to eq({})
    end

    it "populates header and source filepaths for TEST_PUBLIC type" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      allow(@file_finder).to receive(:find_source_file).with('module1', :ignore).and_return('/path/to/module1.c')
      
      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to eq('/path/to/module1.c')
    end

    it "populates header and source filepaths for TEST_PRIVATE type" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PRIVATE],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      allow(@file_finder).to receive(:find_source_file).with('module1', :ignore).and_return('/path/to/module1.c')
      
      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to eq('/path/to/module1.c')
    end

    it "populates header and source filepaths for TEST_PUBLIC and TEST_PRIVATE types" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC, Partials::TEST_PRIVATE],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      allow(@file_finder).to receive(:find_source_file).with('module1', :ignore).and_return('/path/to/module1.c')
      
      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to eq('/path/to/module1.c')
    end

    it "populates only header filepath for MOCK_PUBLIC type" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::MOCK_PUBLIC],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      expect(@file_finder).not_to receive(:find_source_file)

      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to be_nil
    end

    it "populates only header filepath for MOCK_PRIVATE type" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::MOCK_PRIVATE],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      expect(@file_finder).not_to receive(:find_source_file)

      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to be_nil
    end

    it "populates filepaths for multiple modules" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        ),
        'module2' => OpenStruct.new(
          module: 'module2',
          types: [Partials::TEST_PRIVATE],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }
      
      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      allow(@file_finder).to receive(:find_source_file).with('module1', :ignore).and_return('/path/to/module1.c')
      allow(@file_finder).to receive(:find_header_file).with('module2', :ignore).and_return('/path/to/module2.h')
      allow(@file_finder).to receive(:find_source_file).with('module2', :ignore).and_return('/path/to/module2.c')
      
      @helper.config_populate_filepaths(configs)
      
      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to eq('/path/to/module1.c')
      expect(configs['module2'].header.filepath).to eq('/path/to/module2.h')
      expect(configs['module2'].source.filepath).to eq('/path/to/module2.c')
    end
  end

  context "#filter_and_transform_funcs" do
    before(:each) do
      @mock_func1 = double('func1',
        name: 'publicFunc',
        signature: 'void publicFunc(void)'
      )
      @mock_func2 = double('func2',
        name: 'staticFunc',
        signature: 'static void staticFunc(void)'
      )
      @mock_func3 = double('func3',
        name: 'inlineFunc',
        signature: 'inline int inlineFunc(int x)'
      )
    end

    it "returns empty array when functions list is empty" do
      result = @helper.filter_and_transform_funcs([], :public, :impl)
      
      expect(result).to eq([])
    end

    it "filters out functions that don't match visibility" do
      funcs = [@mock_func1, @mock_func2]
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([[], 'void publicFunc(void)'])
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func2.signature, @mock_func2.name)
        .and_return([['static'], 'void staticFunc(void)'])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :public)
        .and_return(true)
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], :public)
        .and_return(false)
      
      mock_transformed = double('transformed_func')
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_transformed)
      
      result = @helper.filter_and_transform_funcs(funcs, :public, :impl)
      
      expect(result).to eq([mock_transformed])
    end

    it "transforms matching functions to implementation type" do
      funcs = [@mock_func1]
      
      decorators = []
      signature = 'void publicFunc(void)'
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([decorators, signature])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(decorators, :public)
        .and_return(true)
      
      mock_impl = double('FunctionDefinition')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, signature, :impl)
        .and_return(mock_impl)
      
      result = @helper.filter_and_transform_funcs(funcs, :public, :impl)
      
      expect(result).to eq([mock_impl])
    end

    it "transforms matching functions to interface type" do
      funcs = [@mock_func1]
      
      decorators = []
      signature = 'void publicFunc(void)'
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([decorators, signature])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(decorators, :public)
        .and_return(true)
      
      mock_interface = double('FunctionDeclaration')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, signature, :interface)
        .and_return(mock_interface)
      
      result = @helper.filter_and_transform_funcs(funcs, :public, :interface)
      
      expect(result).to eq([mock_interface])
    end

    it "filters private functions when visibility is :private" do
      funcs = [@mock_func1, @mock_func2]
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([[], 'void publicFunc(void)'])
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func2.signature, @mock_func2.name)
        .and_return([['static'], 'void staticFunc(void)'])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :private)
        .and_return(false)
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], :private)
        .and_return(true)
      
      mock_transformed = double('transformed_func')
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func2, 'void staticFunc(void)', :impl)
        .and_return(mock_transformed)
      
      result = @helper.filter_and_transform_funcs(funcs, :private, :impl)
      
      expect(result).to eq([mock_transformed])
    end

    it "processes multiple matching functions" do
      funcs = [@mock_func1, @mock_func2, @mock_func3]
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([[], 'void publicFunc(void)'])
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func2.signature, @mock_func2.name)
        .and_return([['static'], 'void staticFunc(void)'])
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func3.signature, @mock_func3.name)
        .and_return([['inline'], 'int inlineFunc(int x)'])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :public)
        .and_return(true)
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], :public)
        .and_return(false)
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['inline'], :public)
        .and_return(true)
      
      mock_transformed1 = double('transformed_func1')
      mock_transformed3 = double('transformed_func3')
      
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_transformed1)
      
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func3, 'int inlineFunc(int x)', :impl)
        .and_return(mock_transformed3)
      
      result = @helper.filter_and_transform_funcs(funcs, :public, :impl)
      
      expect(result).to eq([mock_transformed1, mock_transformed3])
    end

    it "returns empty array when no functions match visibility" do
      funcs = [@mock_func1, @mock_func2]
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func1.signature, @mock_func1.name)
        .and_return([[], 'void publicFunc(void)'])
      
      allow(@partializer_parser).to receive(:parse_signature_decorators)
        .with(@mock_func2.signature, @mock_func2.name)
        .and_return([[], 'void staticFunc(void)'])
      
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :private)
        .and_return(false)
      
      result = @helper.filter_and_transform_funcs(funcs, :private, :impl)
      
      expect(result).to eq([])
    end
  end
end