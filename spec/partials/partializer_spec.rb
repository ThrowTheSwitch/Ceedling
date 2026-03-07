
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/includes'
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
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('module.H'), UserInclude.new('MODULE.H'), UserInclude.new('header2.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('module.H'))
    end

    it "returns empty array when only module header is present" do
      includes = [UserInclude.new('module.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes duplicate includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('header1.h'), UserInclude.new('header3.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('header3.h')])
    end

    it "removes duplicate module includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h'), UserInclude.new('module.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "preserves order when removing duplicates" do
      includes = [UserInclude.new('header3.h'), UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('header1.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([UserInclude.new('header3.h'), UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "distinguishes includes with different extensions" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header1.H'), UserInclude.new('header1.hh')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      # Should only remove includes with exact filename match
      expect(result.length).to eq(3)
    end

    it "is not fooled by uncommon file naming conventions" do
      includes = [UserInclude.new('header1.12.h'), UserInclude.new('header1.13.h'), UserInclude.new('header1.14.h')]
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
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
    end

    it "removes partialized module headers from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => { types: [:test_public] }
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "removes multiple partialized module headers" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial1.h'), UserInclude.new('partial2.h'), UserInclude.new('header2.h')]
      partials = {
        'partial1' => nil,
        'partial2' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "preserves includes that are not partialized" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h'), UserInclude.new('header3.h')]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('header3.h')])
    end

    it "removes duplicates after removing partialized headers" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header1.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles case-insensitive module header removal" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('MODULE.H'), UserInclude.new('header2.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles partials with different configuration types" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial1.h'), UserInclude.new('partial2.h'), UserInclude.new('partial3.h')]
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
      
      expect(result).to eq([UserInclude.new('header1.h')])
    end

    it "preserves order of remaining includes" do
      includes = [UserInclude.new('header3.h'), UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header3.h'), UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles empty partials hash" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('module.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles complex scenario with module header, partials, and duplicates" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('header2.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header3.h')
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
      
      expect(result).to eq([UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('header3.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end
  end

  ###
  ### remap_implementation_source_includes()
  ###

  context "#remap_implementation_source_includes" do
    it "returns implementation header when input is empty and no partials" do
      includes = []
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to eq([impl_header])
    end

    it "adds implementation header to includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h')]
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "removes module's own header from includes" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('header2.h')]
      partials = {}
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('module.h'))
    end

    it "remaps mockable public partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "remaps mockable private partial to interface header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PRIVATE])
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "remaps multiple mockable partials to interface headers" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial1.h'), UserInclude.new('partial2.h'), UserInclude.new('header2.h')]
      partials = {
        'partial1' => OpenStruct.new(types: [Partials::MOCK_PUBLIC]),
        'partial2' => OpenStruct.new(types: [Partials::MOCK_PRIVATE])
      }
      impl_filename = 'module_impl.h'
      interface_filename1 = 'partial1_module_interface.h'
      interface_filename2 = 'partial2_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header1 = UserInclude.new(interface_filename1)
      interface_header2 = UserInclude.new(interface_filename2)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface_filename1)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial2')
        .and_return(interface_filename2)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include(interface_header2)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "remaps testable partial to implementation header" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::TEST_PUBLIC])
      }
      filename = 'module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('partial_module.h'))
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "remaps mix of mockable and testable partials" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial1.h'), UserInclude.new('partial2.h'), UserInclude.new('header2.h')]
      partials = {
        'partial1' => OpenStruct.new(types: [Partials::MOCK_PUBLIC]),
        'partial2' => OpenStruct.new(types: [Partials::TEST_PRIVATE])
      }
      impl_filename = 'module_impl.h'
      interface1_filename = 'partial1_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header1 = UserInclude.new(interface1_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial1')
        .and_return(interface1_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header1)
      expect(result).to include(UserInclude.new('partial2.h'))
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial1.h'))
    end

    it "removes duplicates after remapping" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('header1.h'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_filename = 'module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result.count(UserInclude.new('header1.h'))).to eq(1)
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header2.h'))
    end

    it "handles case-insensitive module header removal" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('module.h'), UserInclude.new('MODULE.H'), UserInclude.new('header2.h')]
      partials = {}
      filename ='module_impl.h'
      impl_header = UserInclude.new(filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles case-insensitive partial module remapping" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('partial_module.h'), UserInclude.new('PARTIAL_MODULE.H'), UserInclude.new('header2.h')]
      partials = {
        'partial_module' => OpenStruct.new(types: [Partials::MOCK_PUBLIC])
      }
      impl_filename ='module_impl.h'
      interface_filename = 'partial_module_interface.h'
      impl_header = UserInclude.new(impl_filename)
      interface_header = UserInclude.new(interface_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with('module')
        .and_return(impl_filename)
      
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with('partial_module')
        .and_return(interface_filename)
      
      result = @partializer.remap_implementation_source_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to include(impl_header)
      expect(result).to include(interface_header)
      expect(result).to include(UserInclude.new('header1.h'))
      expect(result).to include(UserInclude.new('header2.h'))
      expect(result).not_to include(UserInclude.new('partial_module.h'))
      expect(result).not_to include(UserInclude.new('PARTIAL_MODULE.H'))
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
      
      expect(CExtractor).to receive(:from_file).with(UserInclude.new('/path/to/header.h')).and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(header_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: UserInclude.new('/path/to/header.h'),
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
      
      expect(CExtractor).to receive(:from_file).with(UserInclude.new('/path/to/header.h')).and_return(header_extractinator)
      expect(CExtractor).to receive(:from_file).with('/path/to/source.c').and_return(source_extractinator)
      expect(header_extractinator).to receive(:extract_contents).and_return(header_contents)
      expect(source_extractinator).to receive(:extract_contents).and_return(source_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: UserInclude.new('/path/to/header.h'),
        source_filepath: '/path/to/source.c'
      )
      
      expect(result.function_definitions).to eq(header_contents.function_definitions + source_contents.function_definitions)
      expect(result.variables).to eq(header_contents.variables + source_contents.variables)
    end

    it "returns empty CModule when header file has no contents" do
      empty_contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      
      expect(CExtractor).to receive(:from_file).with(UserInclude.new('/path/to/header.h')).and_return(@mock_extractinator)
      expect(@mock_extractinator).to receive(:extract_contents).and_return(empty_contents)
      
      result = @partializer.extract_module_contents(
        header_filepath: UserInclude.new('/path/to/header.h'),
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
      source, header = @partializer.reconstruct_variables(variables: [])
      
      expect(source).to eq([])
      expect(header).to eq([])
    end

    it "returns variable unchanged when no keywords present" do
      variables = ['int counter;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int counter;'])
      expect(header).to eq(['extern int counter;'])
    end

    it "removes static keyword from variable declaration" do
      variables = ['static int counter;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int counter;'])
      expect(header).to eq(['extern int counter;'])
    end

    it "removes const keyword from variable declaration" do
      variables = ['const int MAX_VALUE;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int MAX_VALUE;'])
      expect(header).to eq(['extern int MAX_VALUE;'])
    end

    it "removes volatile keyword from variable declaration" do
      variables = ['volatile int status;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int status;'])
      expect(header).to eq(['extern int status;'])
    end

    it "removes multiple keywords from single declaration" do
      variables = ['static const int MAX_VALUE;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int MAX_VALUE;'])
      expect(header).to eq(['extern int MAX_VALUE;'])
    end

    it "removes all type qualifiers from declaration" do
      variables = ['static const volatile int flags;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int flags;'])
      expect(header).to eq(['extern int flags;'])
    end

    it "preserves variable names containing keyword substrings" do
      variables = ['int my_static_var;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int my_static_var;'])
      expect(header).to eq(['extern int my_static_var;'])
    end

    it "handles pointer declarations" do
      variables = ['static int* ptr;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int* ptr;'])
      expect(header).to eq(['extern int* ptr;'])
    end

    it "handles array declarations" do
      variables = ['static int array[10];']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int array[10];'])
      expect(header).to eq(['extern int array[10];'])
    end

    it "handles complex pointer declarations" do
      variables = ['const char* const ptr;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['char* ptr;'])
      expect(header).to eq(['extern char* ptr;'])
    end

    it "normalizes multiple spaces to single space" do
      variables = ['static  const   int    value;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int value;'])
      expect(header).to eq(['extern int value;'])
    end

    it "removes leading and trailing whitespace" do
      variables = ['  static int counter;  ']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int counter;'])
      expect(header).to eq(['extern int counter;'])
    end

    it "processes multiple variable declarations" do
      variables = [
        'static int counter;',
        'const float pi;',
        'volatile bool flag;'
      ]
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq([
        'int counter;',
        'float pi;',
        'bool flag;'
      ])
      expect(header).to eq([
        'extern int counter;',
        'extern float pi;',
        'extern bool flag;'
      ])
    end

    it "handles struct declarations with keywords" do
      variables = ['static struct Point position;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['struct Point position;'])
      expect(header).to eq(['extern struct Point position;'])
    end

    it "handles typedef declarations with keywords" do
      variables = ['static MyType_t instance;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['MyType_t instance;'])
      expect(header).to eq(['extern MyType_t instance;'])
    end

    it "handles unsigned types with keywords" do
      variables = ['static unsigned int count;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['unsigned int count;'])
      expect(header).to eq(['extern unsigned int count;'])
    end

    it "handles long types with keywords" do
      variables = ['static long long int big_number;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['long long int big_number;'])
      expect(header).to eq(['extern long long int big_number;'])
    end

    it "handles function pointer declarations" do
      variables = ['static void (*callback)(int);']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['void (*callback)(int);'])
      expect(header).to eq(['extern void (*callback)(int);'])
    end

    it "preserves initialization values" do
      variables = ['static int counter = 0;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int counter = 0;'])
      expect(header).to eq(['extern int counter = 0;'])
    end

    it "handles complex initialization with keywords" do
      variables = ['static const int values[] = {1, 2, 3};']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int values[] = {1, 2, 3};'])
      expect(header).to eq(['extern int values[] = {1, 2, 3};'])
    end

    it "handles keywords in middle of declaration" do
      variables = ['int static counter;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int counter;'])
      expect(header).to eq(['extern int counter;'])
    end

    it "handles multiple const keywords" do
      variables = ['const int* const ptr;']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['int* ptr;'])
      expect(header).to eq(['extern int* ptr;'])
    end

    it "does not remove keywords from string literals" do
      variables = ['char* str = "static const";']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq(['char* str = "static const";'])
      expect(header).to eq(['extern char* str = "static const";'])
    end

    it "handles empty string in variables array" do
      variables = ['']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq([])
      expect(header).to eq([])
    end

    it "handles whitespace-only string in variables array" do
      variables = ['   ']
      
      source, header = @partializer.reconstruct_variables(variables: variables)
      
      expect(source).to eq([])
      expect(header).to eq([])
    end

    it "preserves original array and returns new array" do
      original_variables = ['static int counter;']
      
      source, header = @partializer.reconstruct_variables(variables: original_variables)
      
      expect(original_variables).to eq(['static int counter;'])
      expect(source).to eq(['int counter;'])
      expect(source).not_to equal(original_variables)
      expect(header).to eq(['extern int counter;'])
      expect(header).not_to equal(original_variables)
    end
  end

end