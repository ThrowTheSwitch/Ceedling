
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
    @partializer_helper = double("PartializerHelper")
    @c_extractor        = double("CExtractor")
    @file_path_utils    = double("FilePathUtils")
    @loginator          = double("Loginator")

    @partializer = described_class.new(
      {
        :partializer_helper => @partializer_helper,
        :c_extractor        => @c_extractor,
        :file_path_utils    => @file_path_utils,
        :loginator          => @loginator
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
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('module.H'))
    end

    it "returns empty array when only module header is present" do
      includes = [UserInclude.new('module.h')]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes duplicate includes" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('header2.h'), 
        UserInclude.new('header1.h'), 
        UserInclude.new('header3.h')
      ]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to match_array(
        [
          UserInclude.new('header1.h'),
          UserInclude.new('header2.h'),
          UserInclude.new('header3.h')
        ]
      )
    end

    it "removes duplicate module includes" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('module.h'), 
        UserInclude.new('header2.h'), 
        UserInclude.new('module.h')
      ]
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
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
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
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
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial_module.h'))
    end

    it "removes multiple partialized module headers" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial1.h'), 
        UserInclude.new('partial2.h'), 
        UserInclude.new('header2.h')
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
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('partial1.h'))
      expect(result).not_to include(UserInclude.new('partial2.h'))
    end

    it "preserves includes that are not partialized" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial_module.h'), 
        UserInclude.new('header2.h'), 
        UserInclude.new('header3.h')
      ]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array(
        [
          UserInclude.new('header1.h'), 
          UserInclude.new('header2.h'), 
          UserInclude.new('header3.h')
        ]
      )
    end

    it "removes duplicates after removing partialized headers" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial_module.h'), 
        UserInclude.new('header1.h'), 
        UserInclude.new('header2.h')
      ]
      partials = {
        'partial_module' => nil
      }
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
    end

    it "handles case-insensitive module header removal" do
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('MODULE.H'),
        UserInclude.new('header2.h')
      ]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
      expect(result).not_to include(UserInclude.new('module.h'))
      expect(result).not_to include(UserInclude.new('MODULE.H'))
    end

    it "handles partials with different configuration types" do
      includes = [
        UserInclude.new('header1.h'), 
        UserInclude.new('partial1.h'), 
        UserInclude.new('partial2.h'), 
        UserInclude.new('partial3.h')
      ]
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
      
      expect(result).to match_array([UserInclude.new('header1.h')])
    end

    it "handles empty partials hash" do
      includes = [UserInclude.new('header1.h'), UserInclude.new('header2.h'), UserInclude.new('module.h')]
      partials = {}
      result = @partializer.remap_implementation_header_includes(
        name: 'module',
        includes: includes,
        partials: partials
      )
      
      expect(result).to match_array([UserInclude.new('header1.h'), UserInclude.new('header2.h')])
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
      
      expect(result).to match_array(
        [
          UserInclude.new('header1.h'),
          UserInclude.new('header2.h'),
          UserInclude.new('header3.h')
        ]
      )
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
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header2.h')
      ]
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
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial1.h'),
        UserInclude.new('partial2.h'),
        UserInclude.new('header2.h')
      ]
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
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('header1.h'),
        UserInclude.new('header2.h')
      ]
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
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('module.h'),
        UserInclude.new('MODULE.H'),
        UserInclude.new('header2.h')
      ]
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
      includes = [
        UserInclude.new('header1.h'),
        UserInclude.new('partial_module.h'),
        UserInclude.new('PARTIAL_MODULE.H'),
        UserInclude.new('header2.h')
      ]
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
      @name = 'TestModule'

      # associate_function_line_numbers is called for every file processed; stub by default
      allow(@partializer_helper).to receive(:associate_function_line_numbers)
      # static var extraction/promotion called for every file processed; stub by default
      allow(@partializer_helper).to receive(:extract_function_scope_static_vars).and_return([])
      allow(@partializer_helper).to receive(:collect_module_variables)
    end

    it "returns empty CModule when both preprocessed_filepaths are nil" do
      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', preprocessed_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', preprocessed_filepath: nil)
      )

      expect(@c_extractor).not_to receive(:from_file)
      expect(@partializer_helper).not_to receive(:associate_function_line_numbers)
      expect(@partializer_helper).not_to receive(:extract_function_scope_static_vars)
      expect(@partializer_helper).not_to receive(:collect_module_variables)

      result = @partializer.extract_module_contents(@name, config, false)

      expect(result.function_definitions).to eq([])
      expect(result.variables).to eq([])
    end

    it "extracts contents from header preprocessed file only" do
      header_funcs = [
        double('func1', name: 'func1', signature: 'void func1(void)'),
        double('func2', name: 'func2', signature: 'int func2(int x)')
      ]
      header_contents = CExtractor::CModule.new(function_definitions: header_funcs, variables: [])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', preprocessed_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: nil, preprocessed_filepath: nil)
      )

      expect(@c_extractor).to receive(:from_file).with('/build/preproc/header.i').and_return(header_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: header_funcs, filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, false)

      expect(result.function_definitions).to eq(header_funcs)
      expect(result.variables).to eq([])
    end

    it "extracts contents from source preprocessed file only" do
      source_funcs = [
        double('func1', name: 'func1', signature: 'static void func1(void)'),
        double('func2', name: 'func2', signature: 'static int func2(int x)')
      ]
      source_contents = CExtractor::CModule.new(function_definitions: source_funcs, variables: [])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, preprocessed_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', preprocessed_filepath: '/build/preproc/source.i')
      )

      expect(@c_extractor).to receive(:from_file).with('/build/preproc/source.i').and_return(source_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/path/to/source.c', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, false)

      expect(result.function_definitions).to eq(source_funcs)
      expect(result.variables).to eq([])
    end

    it "extracts and merges contents from both source and header preprocessed files" do
      source_funcs = [
        double('func1', name: 'func1', signature: 'static void func1(void)'),
        double('func2', name: 'func2', signature: 'static int func2(int x)')
      ]
      header_funcs = [
        double('func3', name: 'func3', signature: 'void func3(void)'),
        double('func4', name: 'func4', signature: 'int func4(int x)')
      ]
      source_contents = CExtractor::CModule.new(function_definitions: source_funcs, variables: [double('var1')])
      header_contents = CExtractor::CModule.new(function_definitions: header_funcs, variables: [double('var2')])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', preprocessed_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: '/path/to/source.c', preprocessed_filepath: '/build/preproc/source.i')
      )

      allow(@c_extractor).to receive(:from_file).with('/build/preproc/source.i').and_return(source_contents)
      allow(@c_extractor).to receive(:from_file).with('/build/preproc/header.i').and_return(header_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/path/to/source.c', fallback: false
      )
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: header_funcs, filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, false)

      expect(result.function_definitions).to eq(source_funcs + header_funcs)
      expect(result.variables).to eq(source_contents.variables + header_contents.variables)
    end

    it "calls associate_function_line_numbers with the preprocessed expansion filepath, not the preprocessed filepath" do
      source_funcs = [double('func1', name: 'func1')]
      source_contents = CExtractor::CModule.new(function_definitions: source_funcs, variables: [])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, preprocessed_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', preprocessed_filepath: '/build/preproc/module1.i')
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)

      # associate_function_line_numbers must receive the original filepath, not the preprocessed one
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: source_funcs, filepath: '/src/module1.c', fallback: false
      )

      @partializer.extract_module_contents(@name, config, false)
    end

    it "passes extraction name through to associate_function_line_numbers" do
      source_funcs = [double('func1', name: 'func1')]
      source_contents = CExtractor::CModule.new(function_definitions: source_funcs, variables: [])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: nil, preprocessed_filepath: nil),
        source: Partials::ConfigFileInfo.new(filepath: '/src/module1.c', preprocessed_filepath: '/build/preproc/module1.i')
      )

      allow(@c_extractor).to receive(:from_file).and_return(source_contents)

      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: 'SpecificTestName', funcs: source_funcs, filepath: '/src/module1.c', fallback: false
      )

      @partializer.extract_module_contents('SpecificTestName', config, false)
    end

    it "returns empty CModule when a preprocessed file has no contents" do
      empty_contents = CExtractor::CModule.new(function_definitions: [], variables: [])

      config = Partials::Config.new(
        module: 'module1',
        header: Partials::ConfigFileInfo.new(filepath: '/path/to/header.h', preprocessed_filepath: '/build/preproc/header.i'),
        source: Partials::ConfigFileInfo.new(filepath: nil, preprocessed_filepath: nil)
      )

      expect(@c_extractor).to receive(:from_file).and_return(empty_contents)
      expect(@partializer_helper).to receive(:associate_function_line_numbers).with(
        name: @name, funcs: [], filepath: '/path/to/header.h', fallback: false
      )

      result = @partializer.extract_module_contents(@name, config, false)

      expect(result.function_definitions).to eq([])
      expect(result.variables).to eq([])
    end
  end

  ###
  ### reconstruct_functions()
  ###

  context "#reconstruct_functions" do
    it "returns empty arrays when config has no types" do
      contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      config = Partials::Config.new(module: 'module1', types: [])

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
      )

      expect(impl).to eq([])
      expect(interface).to eq([])
    end

    it "returns empty arrays when contents has no function definitions and config has no types" do
      contents = CExtractor::CModule.new(function_definitions: [], variables: [])
      config = Partials::Config.new(module: 'module1', types: [])

      expect(@partializer_helper).not_to receive(:filter_and_transform_funcs)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::TEST_PUBLIC])

      filtered_impl = [{ name: 'public_func', type: :impl }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_impl)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::TEST_PRIVATE])

      filtered_impl = [{ name: 'private_func', type: :impl }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :impl)
        .and_return(filtered_impl)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::MOCK_PUBLIC])

      filtered_interface = [{ name: 'public_func', type: :interface }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :interface)
        .and_return(filtered_interface)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::MOCK_PRIVATE])

      filtered_interface = [{ name: 'private_func', type: :interface }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_interface)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::TEST_PUBLIC, Partials::TEST_PRIVATE])

      filtered_public_impl  = [{ name: 'public_func',  type: :impl }]
      filtered_private_impl = [{ name: 'private_func', type: :impl }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_public_impl)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :impl)
        .and_return(filtered_private_impl)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE])

      filtered_public_interface  = [{ name: 'public_func',  type: :interface }]
      filtered_private_interface = [{ name: 'private_func', type: :interface }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :interface)
        .and_return(filtered_public_interface)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_private_interface)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
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
      config = Partials::Config.new(module: 'module1', types: [Partials::TEST_PUBLIC, Partials::MOCK_PRIVATE])

      filtered_public_impl       = [{ name: 'public_func',  type: :impl }]
      filtered_private_interface = [{ name: 'private_func', type: :interface }]

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :public, :impl)
        .and_return(filtered_public_impl)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(mock_funcs, :private, :interface)
        .and_return(filtered_private_interface)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
      )

      expect(impl).to eq(filtered_public_impl)
      expect(interface).to eq(filtered_private_interface)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :public, :impl)
      expect(@partializer_helper).to have_received(:filter_and_transform_funcs).with(mock_funcs, :private, :interface)
    end

    it "handles empty types in config" do
      mock_funcs = [
        double('func1', name: 'public_func'),
        double('func2', name: 'private_func')
      ]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      config = Partials::Config.new(module: 'module1', types: [])

      expect(@partializer_helper).not_to receive(:filter_and_transform_funcs)

      impl, interface = @partializer.reconstruct_functions(
        contents: contents,
        config: config
      )

      expect(impl).to eq([])
      expect(interface).to eq([])
    end

    it "raises error for invalid partial type in config" do
      mock_funcs = [double('func1', name: 'public_func')]
      contents = CExtractor::CModule.new(function_definitions: mock_funcs, variables: [])
      config = Partials::Config.new(module: 'module1', types: [:invalid_type])

      expect {
        @partializer.reconstruct_functions(
          contents: contents,
          config: config
        )
      }.to raise_error(ArgumentError)
    end
  end

end