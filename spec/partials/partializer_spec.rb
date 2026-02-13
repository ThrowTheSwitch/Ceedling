
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer'
require 'ostruct'

describe Partializer do
  before(:each) do
    @partializer_helper = double( "PartializerHelper" )
    @file_path_utils = double( "FilePathUtils" )
    @loginator = double( "Loginator" )

    @partializer = described_class.new(
      {
        :partializer_helper => @partializer_helper,
        :file_path_utils => @file_path_utils,
        :loginator => @loginator
      }
    )
  end

  ###
  ### assemble_configs()
  ###

  context "#assemble_configs" do
    it "returns empty hash when test_context_configs is empty" do
      test_context_configs = []
      
      result = @partializer.assemble_configs(test_context_configs: test_context_configs)
      
      expect(result).to eq({})
    end

    it "delegates config assembly to helper methods in correct sequence" do
      test_context_configs = [
        { Partials::TEST_PUBLIC => 'module1' },
        { Partials::MOCK_PRIVATE => 'module2' }
      ]
      
      mock_configs = {
        'module1' => OpenStruct.new(module: 'module1', types: [Partials::TEST_PUBLIC]),
        'module2' => OpenStruct.new(module: 'module2', types: [Partials::MOCK_PRIVATE])
      }
      
      # Set up expectations for helper method calls
      expect(@partializer_helper).to receive(:manufacture_partial_configs)
        .with(test_context_configs)
        .and_return(mock_configs)
        .ordered
      
      expect(@partializer_helper).to receive(:config_collect_partial_types)
        .with(test_context_configs, mock_configs)
        .ordered
      
      expect(@partializer_helper).to receive(:validate_partial_configs)
        .with(mock_configs)
        .ordered
      
      expect(@partializer_helper).to receive(:config_populate_filepaths)
        .with(mock_configs)
        .ordered
      
      result = @partializer.assemble_configs(test_context_configs: test_context_configs)
      
      expect(result).to eq(mock_configs)
    end
  end

  ###
  ### sanitize_includes()
  ###

  context "#sanitize_includes" do
    it "returns empty array when input is empty" do
      includes = []
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes the module's own header from includes list with case-insensitivity" do
      includes = ['header1.h', 'module.h', 'module.H', 'MODULE.H', 'header2.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('module.h')
      expect(result).not_to include('module.H')
    end

    it "returns empty array when only module header is present" do
      includes = ['module.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes duplicate includes" do
      includes = ['header1.h', 'header2.h', 'header1.h', 'header3.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h', 'header3.h'])
    end

    it "removes duplicate module includes" do
      includes = ['header1.h', 'module.h', 'header2.h', 'module.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h'])
    end

    it "preserves order when removing duplicates" do
      includes = ['header3.h', 'header1.h', 'header2.h', 'header1.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header3.h', 'header1.h', 'header2.h'])
    end

    it "distinguishes includes with different extensions" do
      includes = ['header1.h', 'header1.H', 'header1.hh']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      # Should only remove includes with extact filename match
      expect(result.length).to eq(3)
    end

    it "is not fooled by uncommon file naming conventions" do
      includes = ['header1.12.h', 'header1.13.h', 'header1.14.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      # Should only remove includes with extact filename match
      expect(result.length).to eq(3)
    end
  end

  ###
  ### remap_implementation_header_includes()
  ###

  context "#remap_implementation_header_includes" do
    it "returns empty array when input is empty and no partials" do
      includes = []
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([])
    end

    it "removes module's own header from includes" do
      includes = ['header1.h', 'module.h', 'header2.h']
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('module.h')
    end

    it "removes partialized module headers from includes" do
      includes = ['header1.h', 'partial_module.h', 'header2.h']
      partials = {
        'partial_module' => { types: [:test_public] }
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('partial_module.h')
    end

    it "removes multiple partialized module headers" do
      includes = ['header1.h', 'partial1.h', 'partial2.h', 'header2.h']
      partials = {
        'partial1' => nil,
        'partial2' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('partial1.h')
      expect(result).not_to include('partial2.h')
    end

    it "preserves includes that are not partialized" do
      includes = ['header1.h', 'partial_module.h', 'header2.h', 'header3.h']
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h', 'header3.h'])
    end

    it "removes duplicates after removing partialized headers" do
      includes = ['header1.h', 'partial_module.h', 'header1.h', 'header2.h']
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
    end

    it "handles case-insensitive module header removal" do
      includes = ['header1.h', 'module.h', 'MODULE.H', 'header2.h']
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('module.h')
      expect(result).not_to include('MODULE.H')
    end

    it "handles partials with different configuration types" do
      includes = ['header1.h', 'partial1.h', 'partial2.h', 'partial3.h']
      partials = {
        'partial1' => nil,
        'partial2' => nil,
        'partial3' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h'])
    end

    it "preserves order of remaining includes" do
      includes = ['header3.h', 'header1.h', 'partial_module.h', 'header2.h']
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header3.h', 'header1.h', 'header2.h'])
    end

    it "handles empty partials hash" do
      includes = ['header1.h', 'header2.h', 'module.h']
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h'])
    end

    it "handles complex scenario with module header, partials, and duplicates" do
      includes = [
        'header1.h',
        'module.h',
        'partial1.h',
        'header2.h',
        'partial2.h',
        'header1.h',
        'header3.h'
      ]
      partials = {
        'partial1' => nil,
        'partial2' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq(['header1.h', 'header2.h', 'header3.h'])
      expect(result).not_to include('module.h')
      expect(result).not_to include('partial1.h')
      expect(result).not_to include('partial2.h')
    end
  end

  ###
  ### remap_implementation_source_includes()
  ###

  context "#remap_implementation_source_includes" do
    it "returns implementation header when input is empty and no partials" do
      includes = []
      partials = {}
      impl_header = 'module_impl.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([impl_header])
    end

    it "adds implementation header to includes" do
      includes = ['header1.h', 'header2.h']
      partials = {}
      impl_header = 'module_impl.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
    end

    it "removes module's own header from includes" do
      includes = ['header1.h', 'module.h', 'header2.h']
      partials = {}
      impl_header = 'module_impl.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('module.h')
    end

    it "remaps mockable public partial to interface header" do
      includes = ['header1.h', 'partial_module.h', 'header2.h']
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_header = 'module_impl.h'
      interface_header = 'partial_module_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('partial_module.h')
    end

    it "remaps mockable private partial to interface header" do
      includes = ['header1.h', 'partial_module.h', 'header2.h']
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PRIVATE])
      }
      impl_header = 'module_impl.h'
      interface_header = 'partial_module_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('partial_module.h')
    end

    it "remaps multiple mockable partials to interface headers" do
      includes = ['header1.h', 'partial1.h', 'partial2.h', 'header2.h']
      partials = {
        'partial1' => OpenStruct.new(types: [Partials::MOCK_PUBLIC]),
        'partial2' => OpenStruct.new(types: [Partials::MOCK_PRIVATE])
      }
      impl_header = 'module_impl.h'
      interface_header1 = 'partial1_interface.h'
      interface_header2 = 'partial2_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface_header1)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial2')
        .and_return(interface_header2)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include(interface_header2)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('partial1.h')
      expect(result).not_to include('partial2.h')
    end

    it "remaps testable partial to implementation header" do
      includes = ['header1.h', 'partial_module.h', 'header2.h']
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::TEST_PUBLIC])
      }
      impl_header = 'module_impl.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include('header1.h')
      expect(result).to include('partial_module.h')
      expect(result).to include('header2.h')
    end

    it "remaps mix of mockable and testable partials" do
      includes = ['header1.h', 'partial1.h', 'partial2.h', 'header2.h']
      partials = {
        'partial1' => OpenStruct.new(types: [Partials::MOCK_PUBLIC]),
        'partial2' => OpenStruct.new(types: [Partials::TEST_PRIVATE])
      }
      impl_header = 'module_impl.h'
      interface_header1 = 'partial1_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface_header1)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include('partial2.h')
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('partial1.h')
    end

    it "removes duplicates after remapping" do
      includes = ['header1.h', 'partial_module.h', 'header1.h', 'header2.h']
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_header = 'module_impl.h'
      interface_header = 'partial_module_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result.count('header1.h')).to eq(1)
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include('header2.h')
    end

    it "handles case-insensitive module header removal" do
      includes = ['header1.h', 'module.h', 'MODULE.H', 'header2.h']
      partials = {}
      impl_header = 'module_impl.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('module.h')
      expect(result).not_to include('MODULE.H')
    end

    it "handles case-insensitive partial module remapping" do
      includes = ['header1.h', 'partial_module.h', 'PARTIAL_MODULE.H', 'header2.h']
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_header = 'module_impl.h'
      interface_header = 'partial_module_interface.h'
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_header)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_header)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include('header1.h')
      expect(result).to include('header2.h')
      expect(result).not_to include('partial_module.h')
      expect(result).not_to include('PARTIAL_MODULE.H')
    end
  end

  ###
  ### extract_module_contents()
  ###

  context "#extract_module_contents" do
    before(:each) do
      @mock_extractinator = double('CExtractor')
      allow(CExtractor).to receive(:from_file).and_return(@mock_extractinator)
    end

    it "returns empty CModule when both filepaths are nil" do
      result = @partializer.extract_module_contents(
        header_filepath: nil,
        source_filepath: nil
      )

      expect(CExtractor).not_to receive(:from_file).with(nil)

      expect(result.function_definitions).to eq([])
      expect(result.variables).to eq([])
    end

    it "extracts contents from header file only" do
      header_contents = CExtractor::CModule.new(
        function_definitions: [
          double('func1', name: 'func1', signature: 'void func1(void)'),
          double('func2', name: 'func2', signature: 'int func2(int x)')
        ],
        variables: []
      )
      
      expect(CExtractor).to receive(:from_file).with('/path/to/header.h').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(header_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: '/path/to/header.h',
        source_filepath: nil
      )
      
      expect(result).to eq(header_contents)
    end

    it "extracts contents from source file only" do
      source_contents = CExtractor::CModule.new(
        function_definitions: [
          double('func1', name: 'func1', signature: 'static void func1(void)'),
          double('func2', name: 'func2', signature: 'static int func2(int x)')
        ],
        variables: []
      )
      
      expect(CExtractor).to receive(:from_file).with('/path/to/source.c').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(source_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: nil,
        source_filepath: '/path/to/source.c'
      )
      
      expect(result).to eq(source_contents)
    end

    it "extracts and combines contents from both header and source files" do
      header_contents = CExtractor::CModule.new(
        function_definitions: [
          double('func1', name: 'func1', signature: 'void func1(void)'),
          double('func2', name: 'func2', signature: 'int func2(int x)')
        ],
        variables: [double('var1', name: 'header_var')]
      )
      source_contents = CExtractor::CModule.new(
        function_definitions: [
          double('func3', name: 'func3', signature: 'static void func3(void)'),
          double('func4', name: 'func4', signature: 'static int func4(int x)')
        ],
        variables: [double('var2', name: 'source_var')]
      )
      
      header_extractinator = double('header_extractinator')
      source_extractinator = double('source_extractinator')
      
      expect(CExtractor).to receive(:from_file).with('/path/to/header.h').and_return(header_extractinator)
      expect(CExtractor).to receive(:from_file).with('/path/to/source.c').and_return(source_extractinator)
      expect(header_extractinator).to receive(:extract_contents).and_return(header_contents)
      expect(source_extractinator).to receive(:extract_contents).and_return(source_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: '/path/to/header.h',
        source_filepath: '/path/to/source.c'
      )
      
      expect(result.function_definitions).to eq(header_contents.function_definitions + source_contents.function_definitions)
      expect(result.variables).to eq(header_contents.variables + source_contents.variables)
    end

    it "returns empty CModule when header file has no contents" do
      empty_contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      
      expect(CExtractor).to receive(:from_file).with('/path/to/header.h').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(empty_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: '/path/to/header.h',
        source_filepath: nil
      )
      
      expect(result.function_definitions).to eq([])
      expect(result.variables).to eq([])
    end

    it "returns empty CModule when source file has no contents" do
      empty_contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      
      expect(CExtractor).to receive(:from_file).with('/path/to/source.c').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(empty_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: nil,
        source_filepath: '/path/to/source.c'
      )
      
      expect(result.function_definitions).to eq([])
      expect(result.variables).to eq([])
    end
  end

  ###
  ### reconstruct_functions()
  ###

  context "#reconstruct_functions" do
    it "returns empty arrays when no functions are provided" do
      contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      types = []
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq([])
      expect(interface).to eq([])
    end

    it "extracts public functions for TEST_PUBLIC type" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::TEST_PUBLIC]
      
      filtered_impl = [{ name: 'public_func', type: :impl }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_impl)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq(filtered_impl)
      expect(interface).to eq([])
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :impl)
    end

    it "extracts private functions for TEST_PRIVATE type" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::TEST_PRIVATE]
      
      filtered_impl = [{ name: 'private_func', type: :impl }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :impl)
        .and_return(filtered_impl)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq(filtered_impl)
      expect(interface).to eq([])
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :impl)
    end

    it "extracts public interface for MOCK_PUBLIC type" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::MOCK_PUBLIC]
      
      filtered_interface = [{ name: 'public_func', type: :interface }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :interface)
        .and_return(filtered_interface)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq([])
      expect(interface).to eq(filtered_interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :interface)
    end

    it "extracts private interface for MOCK_PRIVATE type" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::MOCK_PRIVATE]
      
      filtered_interface = [{ name: 'private_func', type: :interface }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_interface)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq([])
      expect(interface).to eq(filtered_interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :interface)
    end

    it "extracts both public and private functions for multiple TEST types" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::TEST_PUBLIC, Partials::TEST_PRIVATE]
      
      filtered_public_impl = [{ name: 'public_func', type: :impl }]
      filtered_private_impl = [{ name: 'private_func', type: :impl }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_public_impl)
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :impl)
        .and_return(filtered_private_impl)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq(filtered_public_impl + filtered_private_impl)
      expect(interface).to eq([])
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :impl)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :impl)
    end

    it "extracts both public and private interfaces for multiple MOCK types" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE]
      
      filtered_public_interface = [{ name: 'public_func', type: :interface }]
      filtered_private_interface = [{ name: 'private_func', type: :interface }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :interface)
        .and_return(filtered_public_interface)
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_private_interface)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq([])
      expect(interface).to eq(filtered_public_interface + filtered_private_interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :interface)
    end

    it "extracts mixed TEST and MOCK types" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE]
      
      filtered_public_impl = [{ name: 'public_func', type: :impl }]
      filtered_private_interface = [{ name: 'private_func', type: :interface }]
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_public_impl)
      
      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_private_interface)
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq(filtered_public_impl)
      expect(interface).to eq(filtered_private_interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :impl)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :interface)
    end

    it "handles empty types array" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = []
      
      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        types: types
      )
      
      expect(impl).to eq([])
      expect(interface).to eq([])
    end

    it "raises error for invalid partial type" do
      mock_funcs = [double('func1', name: 'public_func')]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      types = [:invalid_type]
      
      expect {
        @partializer.reconstruct_functions(
          contents: contents,
          types: types
        )
      }.to raise_error(ArgumentError)
    end
  end

  ###
  ### reconstruct_variables()
  ###

  context "#reconstruct_variables" do
    it "returns empty array when no variables are provided" do
      result = @partializer.reconstruct_variables(variables: [])
      
      expect(result).to eq([])
    end

    it "returns variable unchanged when no keywords present" do
      variables = ['int counter;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int counter;'])
    end

    it "removes static keyword from variable declaration" do
      variables = ['static int counter;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int counter;'])
    end

    it "removes const keyword from variable declaration" do
      variables = ['const int MAX_VALUE;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int MAX_VALUE;'])
    end

    it "removes volatile keyword from variable declaration" do
      variables = ['volatile int status;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int status;'])
    end

    it "removes multiple keywords from single declaration" do
      variables = ['static const int MAX_VALUE;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int MAX_VALUE;'])
    end

    it "removes all type qualifiers from declaration" do
      variables = ['static const volatile int flags;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int flags;'])
    end

    it "preserves variable names containing keyword substrings" do
      variables = ['int my_static_var;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int my_static_var;'])
    end

    it "handles pointer declarations" do
      variables = ['static int* ptr;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int* ptr;'])
    end

    it "handles array declarations" do
      variables = ['static int array[10];']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int array[10];'])
    end

    it "handles complex pointer declarations" do
      variables = ['const char* const ptr;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['char* ptr;'])
    end

    it "normalizes multiple spaces to single space" do
      variables = ['static  const   int    value;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int value;'])
    end

    it "removes leading and trailing whitespace" do
      variables = ['  static int counter;  ']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int counter;'])
    end

    it "processes multiple variable declarations" do
      variables = [
        'static int counter;',
        'const float pi;',
        'volatile bool flag;'
      ]
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq([
        'int counter;',
        'float pi;',
        'bool flag;'
      ])
    end

    it "handles struct declarations with keywords" do
      variables = ['static struct Point position;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['struct Point position;'])
    end

    it "handles typedef declarations with keywords" do
      variables = ['static MyType_t instance;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['MyType_t instance;'])
    end

    it "handles unsigned types with keywords" do
      variables = ['static unsigned int count;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['unsigned int count;'])
    end

    it "handles long types with keywords" do
      variables = ['static long long int big_number;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['long long int big_number;'])
    end

    it "handles function pointer declarations" do
      variables = ['static void (*callback)(int);']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['void (*callback)(int);'])
    end

    it "preserves initialization values" do
      variables = ['static int counter = 0;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int counter = 0;'])
    end

    it "handles complex initialization with keywords" do
      variables = ['static const int values[] = {1, 2, 3};']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int values[] = {1, 2, 3};'])
    end

    it "handles keywords in middle of declaration" do
      variables = ['int static counter;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int counter;'])
    end

    it "handles multiple const keywords" do
      variables = ['const int* const ptr;']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq(['int* ptr;'])
    end

    it "does not remove keywords from string literals" do
      variables = ['char* str = "static const";']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      # Note: This test documents current behavior - the method doesn't 
      # handle string literals specially, but since we're removing whole
      # words with word boundaries, it shouldn't match inside strings
      expect(result).to eq(['char* str = "static const";'])
    end

    it "handles empty string in variables array" do
      variables = ['']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq([''])
    end

    it "handles whitespace-only string in variables array" do
      variables = ['   ']
      
      result = @partializer.reconstruct_variables(variables: variables)
      
      expect(result).to eq([''])
    end

    it "preserves original array and returns new array" do
      original_variables = ['static int counter;']
      
      result = @partializer.reconstruct_variables(variables: original_variables)
      
      expect(original_variables).to eq(['static int counter;'])
      expect(result).to eq(['int counter;'])
      expect(result).not_to equal(original_variables)
    end
  end

end