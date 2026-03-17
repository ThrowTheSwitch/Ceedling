
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partializer_utils'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ostruct'

describe PartializerHelper do
  before(:each) do
    @partializer_utils        = double("PartializerUtils")
    @file_finder              = double("FileFinder")
    @c_extractor_declarations = double("CExtractorDeclarations")
    @file_path_utils          = double("FilePathUtils")
    @loginator                = double("Loginator").as_null_object

    @helper = described_class.new(
      {
        :partializer_utils        => @partializer_utils,
        :file_finder              => @file_finder,
        :c_extractor_declarations => @c_extractor_declarations,
        :file_path_utils          => @file_path_utils,
        :loginator                => @loginator
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

    it "populates header and source filepaths for MOCK_PRIVATE type" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::MOCK_PRIVATE],
          header: OpenStruct.new(filepath: nil),
          source: OpenStruct.new(filepath: nil)
        )
      }

      allow(@file_finder).to receive(:find_header_file).with('module1', :ignore).and_return('/path/to/module1.h')
      expect(@file_finder).to receive(:find_source_file).with('module1', :ignore).and_return('/path/to/module1.c')

      @helper.config_populate_filepaths(configs)

      expect(configs['module1'].header.filepath).to eq('/path/to/module1.h')
      expect(configs['module1'].source.filepath).to eq('/path/to/module1.c')
    end

    it "populates header and source filepaths for TEST_PUBLIC, TEST_PRIVATE, and MOCK_PRIVATE types" do
      configs = {
        'module1' => OpenStruct.new(
          module: 'module1',
          types: [Partials::TEST_PUBLIC, Partials::TEST_PRIVATE, Partials::MOCK_PRIVATE],
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
        name:               'publicFunc',
        decorators:         [],
        signature_stripped: 'void publicFunc(void)'
      )
      @mock_func2 = double('func2',
        name:               'staticFunc',
        decorators:         ['static'],
        signature_stripped: 'void staticFunc(void)'
      )
      @mock_func3 = double('func3',
        name:               'inlineFunc',
        decorators:         ['inline'],
        signature_stripped: 'int inlineFunc(int x)'
      )
    end

    it "returns empty array when functions list is empty" do
      result = @helper.filter_and_transform_funcs([], :public, :impl)
      expect(result).to eq([])
    end

    it "filters out public function when :private visibility requested" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :private)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func1], :private, :impl)
      expect(result).to eq([])
    end

    it "filters out private function when :public visibility requested" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], :public)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func2], :public, :impl)
      expect(result).to eq([])
    end

    it "transforms a matching public function to :impl type" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :public)
        .and_return(true)

      mock_impl = double('FunctionDefinition')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_impl)

      result = @helper.filter_and_transform_funcs([@mock_func1], :public, :impl)
      expect(result).to eq([mock_impl])
    end

    it "transforms a matching public function to :interface type" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :public)
        .and_return(true)

      mock_interface = double('FunctionDeclaration')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :interface)
        .and_return(mock_interface)

      result = @helper.filter_and_transform_funcs([@mock_func1], :public, :interface)
      expect(result).to eq([mock_interface])
    end

    it "returns only the matching function when mixed public/private present" do
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

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2], :public, :impl)
      expect(result).to eq([mock_transformed])
    end

    it "filters to only the private function when :private visibility requested" do
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

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2], :private, :impl)
      expect(result).to eq([mock_transformed])
    end

    it "processes multiple matching functions preserving order" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :public)
        .and_return(true)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], :public)
        .and_return(false)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['inline'], :public)
        .and_return(true)

      mock_result1 = double('result1')
      mock_result3 = double('result3')

      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_result1)
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func3, 'int inlineFunc(int x)', :impl)
        .and_return(mock_result3)

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2, @mock_func3], :public, :impl)
      expect(result).to eq([mock_result1, mock_result3])
    end

    it "returns empty array when no functions match visibility" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], :private)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func1], :private, :impl)
      expect(result).to eq([])
    end
  end

  context "#associate_function_line_numbers" do
    before(:each) do
      @name                 = 'TestModule'
      @filepath             = '/path/to/module.c'
      @preprocessed_filepath = '/build/preproc/module_TestModule.i'

      allow(@file_path_utils).to receive(:form_preprocessed_file_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(@preprocessed_filepath)

      allow(@partializer_utils).to receive(:stamp_source_filepaths)
      allow(@partializer_utils).to receive(:format_line_number_list).and_return([])
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: false" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: true" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: true)
    end

    it "makes no locate calls when funcs is empty" do
      expect(@partializer_utils).not_to receive(:locate_function_in_source)
      expect(@partializer_utils).not_to receive(:locate_function_via_preprocessed)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "constructs preprocessed filepath from name and filepath" do
      expect(@file_path_utils).to receive(:form_preprocessed_file_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(@preprocessed_filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "uses locate_function_in_source for each func when fallback: true" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_function_in_source)
        .with(code_block: func1.code_block, filepath: @filepath)
        .and_return(10)
      expect(@partializer_utils).to receive(:locate_function_in_source)
        .with(code_block: func2.code_block, filepath: @filepath)
        .and_return(25)

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: true)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "uses locate_function_via_preprocessed for each func when fallback: false" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(code_block: func1.code_block, filepath: @filepath, preprocessed_filepath: @preprocessed_filepath)
        .and_return(10)
      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(code_block: func2.code_block, filepath: @filepath, preprocessed_filepath: @preprocessed_filepath)
        .and_return(25)

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: false)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "sets line_num to nil when locate_function_via_preprocessed returns nil" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(nil)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)

      expect(func.line_num).to be_nil
    end

    it "does not call locate_function_via_preprocessed when fallback: true" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_function_via_preprocessed)
      allow(@partializer_utils).to receive(:locate_function_in_source).and_return(1)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: true)
    end

    it "does not call locate_function_in_source when fallback: false" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_function_in_source)
      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(1)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "calls format_line_number_list with funcs and passes result to loginator" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil, name: 'foo')

      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(5)

      expect(@partializer_utils).to receive(:format_line_number_list).with([func]).and_return(["foo(): 5"])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "forwards the constructed preprocessed_filepath to locate_function_via_preprocessed" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      custom_preproc = '/custom/preproc/output.i'
      allow(@file_path_utils).to receive(:form_preprocessed_file_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(custom_preproc)

      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(hash_including(preprocessed_filepath: custom_preproc))
        .and_return(nil)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end
  end

  context "#extract_function_scope_static_vars" do
    context "mock-based delegation tests" do
      it "returns empty array and makes no calls when funcs is empty" do
        expect(@c_extractor_declarations).not_to receive(:try_extract_variable)

        result = @helper.extract_function_scope_static_vars([])
        expect(result).to eq([])
      end

      it "returns empty array when function body has no declarations (scanner returns false immediately)" do
        func = OpenStruct.new(
          name: 'simple',
          code_block: 'void simple(void) { return; }',
          body: '{ return; }'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([false, nil])

        expect(@partializer_utils).not_to receive(:replace_declaration_with_noop)
        expect(@partializer_utils).not_to receive(:rename_c_identifier)

        result = @helper.extract_function_scope_static_vars([func])
        expect(result).to eq([])
      end

      it "returns empty array when variable is found but is non-static" do
        func = OpenStruct.new(
          name: 'simple',
          code_block: 'void simple(void) { int x; return x; }',
          body: '{ int x; return x; }'
        )

        non_static_var = OpenStruct.new(
          original:    'int x',
          name:        'x',
          decorators:  [],
          declaration: 'int x;'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [non_static_var]], [false, nil])

        expect(@partializer_utils).not_to receive(:replace_declaration_with_noop)
        expect(@partializer_utils).not_to receive(:rename_c_identifier)

        result = @helper.extract_function_scope_static_vars([func])
        expect(result).to eq([])
      end

      it "delegates noop and rename calls to utils for a static variable" do
        func = OpenStruct.new(
          name: 'process',
          code_block: 'void process(void) { static int count; count = 0; }',
          body: '{ static int count; count = 0; }'
        )

        var = OpenStruct.new(
          original:    'static int count',
          name:        'count',
          decorators:  ['static'],
          declaration: 'int count;'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [var]], [false, nil])

        placeholder = '__CEEDLING_NOOP_PROCESS_COUNT__'
        noop_text   = "(void)0; /* `#{placeholder}` ... */"

        allow(@partializer_utils).to receive(:replace_declaration_with_noop)
          .and_return(noop_text)
        allow(@partializer_utils).to receive(:rename_c_identifier)
          .and_return('')

        result = @helper.extract_function_scope_static_vars([func])

        expect(@partializer_utils).to have_received(:replace_declaration_with_noop).exactly(2).times
        expect(@partializer_utils).to have_received(:rename_c_identifier).exactly(3).times
        expect(result.first.name).to eq('partial_process_count')
      end

      it "delegates compound noop and rename calls to utils for a compound static declaration" do
        func = OpenStruct.new(
          name: 'calc',
          code_block: 'void calc(void) { static int a, b; a = 0; b = 1; }',
          body: '{ static int a, b; a = 0; b = 1; }'
        )

        shared_original = 'static int a, b;'
        var_a = OpenStruct.new(
          original:    shared_original,
          name:        'a',
          decorators:  ['static'],
          declaration: 'int a;'
        )
        var_b = OpenStruct.new(
          original:    shared_original,
          name:        'b',
          decorators:  ['static'],
          declaration: 'int b;'
        )

        # Scanner returns both vars in one call, then fails
        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [var_a, var_b]], [false, nil])

        placeholder = '__CEEDLING_NOOP_CALC_A__'
        noops       = "(void)0; (void)0; /* `#{placeholder}` ... */"

        allow(@partializer_utils).to receive(:replace_compound_declaration_with_noops)
          .and_return(noops)
        allow(@partializer_utils).to receive(:rename_c_identifier)
          .and_return('')

        result = @helper.extract_function_scope_static_vars([func])

        expect(@partializer_utils).to have_received(:replace_compound_declaration_with_noops)
          .with(anything, shared_original, placeholder, 2)
          .exactly(2).times
        expect(@partializer_utils).to have_received(:rename_c_identifier).exactly(6).times
        expect(result.map(&:name)).to contain_exactly('partial_calc_a', 'partial_calc_b')
      end
    end

    context "end-to-end happy day tests" do
      let(:real_utils) do
        PartializerUtils.new(
          {
            :preprocessinator_code_finder => double("CodeFinder"),
            :loginator                    => double("Loginator").as_null_object
          }
        )
      end

      let(:real_helper) do
        PartializerHelper.new(
          {
            :partializer_utils        => real_utils,
            :file_finder              => double("FileFinder"),
            :c_extractor_declarations => CExtractorDeclarations.new,
            :file_path_utils          => double("FilePathUtils"),
            :loginator                => double("Loginator").as_null_object
          }
        )
      end

      it "excises a single static variable declaration and renames references" do
        func = OpenStruct.new(
          name:       'process',
          body:       "{\n  static int count;\n  return count;\n}",
          code_block: "void process(void) {\n  static int count;\n  return count;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func])

        # One var returned with renamed identifier
        expect(result.length).to eq(1)
        expect(result.first.name).to eq('partial_process_count')

        # No-op placeholder present in code_block
        expect(func.code_block).to include('(void)0;')

        # References renamed throughout code_block
        expect(func.code_block).to include('partial_process_count')

        # Original declaration text preserved inside comment
        expect(func.code_block).to include('static int count')
      end

      it "does not modify code_block when function body has only non-static variables" do
        original_code_block = "void simple(void) {\n  int x = 0;\n  return x;\n}"

        func = OpenStruct.new(
          name:       'simple',
          body:       "{\n  int x = 0;\n  return x;\n}",
          code_block: original_code_block.dup
        )

        result = real_helper.extract_function_scope_static_vars([func])

        expect(result).to eq([])
        expect(func.code_block).to eq(original_code_block)
      end

      it "returns empty array when function has no variable declarations at all" do
        func = OpenStruct.new(
          name:       'empty_func',
          body:       "{\n  return;\n}",
          code_block: "void empty_func(void) {\n  return;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func])
        expect(result).to eq([])
      end

      it "correctly handles a compound static declaration without corrupting comments" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int a, b;\n  a = 0;\n  b = 1;\n}",
          code_block: "void calc(void) {\n  static int a, b;\n  a = 0;\n  b = 1;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func])

        # Two vars returned, both renamed
        expect(result.length).to eq(2)
        expect(result.map(&:name)).to contain_exactly('partial_calc_a', 'partial_calc_b')

        # Exactly two no-ops replace the one compound declaration
        expect(func.code_block.scan('(void)0;').length).to eq(2)

        # Renamed references present in code_block
        expect(func.code_block).to include('partial_calc_a')
        expect(func.code_block).to include('partial_calc_b')

        # Replacement no-op with (incomplete) comment
        expect(func.code_block).to include('(void)0; (void)0; /* `static int a, b;` replaced with no-op')
      end
    end
  end

  context "#collect_module_variables" do
    it "returns empty array when both inputs are empty" do
      result = @helper.collect_module_variables([], [])
      expect(result).to eq([])
    end

    it "appends new variables to existing ones" do
      existing = ['a']
      result   = @helper.collect_module_variables(existing, ['b', 'c'])
      expect(result).to eq(['a', 'b', 'c'])
    end

    it "mutates the existing array in place (concat semantics)" do
      existing = ['a']
      @helper.collect_module_variables(existing, ['b'])
      expect(existing).to eq(['a', 'b'])
    end

    it "appends to empty existing array" do
      result = @helper.collect_module_variables([], ['x', 'y'])
      expect(result).to eq(['x', 'y'])
    end

    it "appends nothing when new array is empty" do
      existing = ['a', 'b']
      result   = @helper.collect_module_variables(existing, [])
      expect(result).to eq(['a', 'b'])
    end
  end

end
