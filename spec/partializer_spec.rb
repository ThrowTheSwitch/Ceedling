
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
    @file_finder = double( "FileFinder" )

    @partializer = described_class.new(
      {
        :partializer_helper => @partializer_helper,
        :file_path_utils => @file_path_utils,
        :file_finder => @file_finder
      }
    )
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

end