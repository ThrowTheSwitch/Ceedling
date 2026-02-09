
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partializer'
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

      expect(result.funcs).to eq([])
      expect(result.vars).to eq([])
    end

    it "extracts contents from header file only" do
      header_contents = CExtractor::CModule.new(
        funcs: [
          double('func1', name: 'func1', signature: 'void func1(void)'),
          double('func2', name: 'func2', signature: 'int func2(int x)')
        ],
        vars: []
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
        funcs: [
          double('func1', name: 'func1', signature: 'static void func1(void)'),
          double('func2', name: 'func2', signature: 'static int func2(int x)')
        ],
        vars: []
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
        funcs: [
          double('func1', name: 'func1', signature: 'void func1(void)'),
          double('func2', name: 'func2', signature: 'int func2(int x)')
        ],
        vars: [double('var1', name: 'header_var')]
      )
      source_contents = CExtractor::CModule.new(
        funcs: [
          double('func3', name: 'func3', signature: 'static void func3(void)'),
          double('func4', name: 'func4', signature: 'static int func4(int x)')
        ],
        vars: [double('var2', name: 'source_var')]
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
      
      expect(result.funcs).to eq(header_contents.funcs + source_contents.funcs)
      expect(result.vars).to eq(header_contents.vars + source_contents.vars)
    end

    it "returns empty CModule when header file has no contents" do
      empty_contents = CExtractor::CModule.new(funcs: [], vars: [])
      
      expect(CExtractor).to receive(:from_file).with('/path/to/header.h').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(empty_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: '/path/to/header.h',
        source_filepath: nil
      )
      
      expect(result.funcs).to eq([])
      expect(result.vars).to eq([])
    end

    it "returns empty CModule when source file has no contents" do
      empty_contents = CExtractor::CModule.new(funcs: [], vars: [])
      
      expect(CExtractor).to receive(:from_file).with('/path/to/source.c').and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(empty_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: nil,
        source_filepath: '/path/to/source.c'
      )
      
      expect(result.funcs).to eq([])
      expect(result.vars).to eq([])
    end
  end

  context "#reconstruct_functions" do
    it "returns empty arrays when no functions are provided" do
      contents = CExtractor::CModule.new(funcs: [], vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
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
      contents = CExtractor::CModule.new(funcs: mock_funcs, vars: [])
      types = [:invalid_type]
      
      expect {
        @partializer.reconstruct_functions(
          contents: contents,
          types: types
        )
      }.to raise_error(ArgumentError)
    end
  end

end