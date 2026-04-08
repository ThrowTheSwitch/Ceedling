
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/includes'
require 'ceedling/partials/partializer'
require 'ceedling/partials/partials'
require 'ostruct'

describe Partializer do
  before(:each) do
    @partializer_helper = double("PartializerHelper")
    @file_finder        = double("FileFinder")
    @c_extractor        = double("CExtractor")
    @file_path_utils    = double("FilePathUtils")
    @loginator          = double("Loginator").as_null_object

    @partializer = described_class.new(
      {
        :partializer_helper => @partializer_helper,
        :file_finder        => @file_finder,
        :c_extractor        => @c_extractor,
        :file_path_utils    => @file_path_utils,
        :loginator          => @loginator
      }
    )
  end

  ###
  ### populate_filepaths()
  ###

  context "#populate_filepaths" do
    def make_tests(present:)
      OpenStruct.new(present?: present)
    end

    def make_mocks(present:, type: nil)
      OpenStruct.new(present?: present, type: type)
    end

    def make_config(tests:, mocks:)
      OpenStruct.new(
        tests:  tests,
        mocks:  mocks,
        header: OpenStruct.new(filepath: nil),
        source: OpenStruct.new(filepath: nil)
      )
    end

    it "returns the configs hash unchanged when empty" do
      result = @partializer.populate_filepaths({})
      expect(result).to eq({})
    end

    it "populates header and source for a test config" do
      configs = { 'mod' => make_config(tests: make_tests(present: true), mocks: make_mocks(present: false)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "populates header only for mock-public config" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PUBLIC)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore).and_return('mod.h')
      expect(@file_finder).not_to receive(:find_source_file)

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to be_nil
    end

    it "populates header and source for mock-private config" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PRIVATE)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "populates header and source when mocks.type is nil" do
      configs = { 'mod' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: nil)) }

      allow(@file_finder).to receive(:find_header_file).with('mod', :ignore).and_return('mod.h')
      allow(@file_finder).to receive(:find_source_file).with('mod', :ignore).and_return('mod.c')

      @partializer.populate_filepaths(configs)

      expect(configs['mod'].header.filepath).to eq('mod.h')
      expect(configs['mod'].source.filepath).to eq('mod.c')
    end

    it "handles multiple modules independently" do
      configs = {
        'a' => make_config(tests: make_tests(present: true),  mocks: make_mocks(present: false)),
        'b' => make_config(tests: make_tests(present: false), mocks: make_mocks(present: true, type: Partials::PUBLIC))
      }

      allow(@file_finder).to receive(:find_header_file).with('a', :ignore).and_return('a.h')
      allow(@file_finder).to receive(:find_source_file).with('a', :ignore).and_return('a.c')
      allow(@file_finder).to receive(:find_header_file).with('b', :ignore).and_return('b.h')
      expect(@file_finder).not_to receive(:find_source_file).with('b', :ignore)

      @partializer.populate_filepaths(configs)

      expect(configs['a'].header.filepath).to eq('a.h')
      expect(configs['a'].source.filepath).to eq('a.c')
      expect(configs['b'].header.filepath).to eq('b.h')
      expect(configs['b'].source.filepath).to be_nil
    end
  end

  ###
  ### validate_config()
  ###

  context "#validate_config" do
    it "delegates to three validation helpers in order" do
      c_module = double("CModule")
      config   = double("Config")
      name     = "test_foo"

      expect(@partializer_helper).to receive(:validate_function_names_exist)
        .with(c_module, config, name).ordered
      expect(@partializer_helper).to receive(:validate_no_additions_subtractions_overlap)
        .with(config, name).ordered
      expect(@partializer_helper).to receive(:validate_additions_subtractions_visibility)
        .with(c_module, config, name).ordered

      @partializer.validate_config(c_module: c_module, config: config, name: name)
    end
  end

  ###
  ### validate_extracted_functions()
  ###

  context "#validate_extracted_functions" do
    def make_impl(name)
      Partials.manufacture_function_definition(
        name: name, signature: "void #{name}(void)", code_block: "void #{name}(void) {}"
      )
    end

    def make_iface(name)
      Partials.manufacture_function_declaration(name: name, signature: "void #{name}(void)")
    end

    it "does not raise when impl is nil" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: nil, interface: [make_iface('foo')]
        )
      }.not_to raise_error
    end

    it "does not raise when interface is nil" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [make_impl('foo')], interface: nil
        )
      }.not_to raise_error
    end

    it "does not raise when impl is empty" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [], interface: [make_iface('foo')]
        )
      }.not_to raise_error
    end

    it "does not raise when interface is empty" do
      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: [make_impl('foo')], interface: []
        )
      }.not_to raise_error
    end

    it "does not raise when impl and interface have no overlapping functions" do
      impl      = [make_impl('foo'), make_impl('bar')]
      interface = [make_iface('baz'), make_iface('qux')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.not_to raise_error
    end

    it "raises CeedlingException when one function appears in both impl and interface" do
      impl      = [make_impl('foo'), make_impl('shared')]
      interface = [make_iface('shared'), make_iface('bar')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.to raise_error(CeedlingException, /shared/)
    end

    it "raises for each overlapping function when multiple functions overlap" do
      impl      = [make_impl('alpha'), make_impl('beta')]
      interface = [make_iface('alpha'), make_iface('beta')]

      expect {
        @partializer.validate_extracted_functions(
          name: 'test_mod', partial: 'mod', impl: impl, interface: interface
        )
      }.to raise_error(CeedlingException)
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

  def make_partial_config(mocks_type: nil, tests_type: nil)
    OpenStruct.new(
      mocks: OpenStruct.new(type: mocks_type),
      tests: OpenStruct.new(type: tests_type)
    )
  end

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
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
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
        'partial_module' => make_partial_config(mocks_type: Partials::PRIVATE)
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
        'partial1' => make_partial_config(mocks_type: Partials::PUBLIC),
        'partial2' => make_partial_config(mocks_type: Partials::PRIVATE)
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
        'partial_module' => make_partial_config(tests_type: Partials::PUBLIC)
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
        'partial1' => make_partial_config(mocks_type: Partials::PUBLIC),
        'partial2' => make_partial_config(tests_type: Partials::PRIVATE)
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
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
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
        'partial_module' => make_partial_config(mocks_type: Partials::PUBLIC)
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
  ### extract_implementation_functions()
  ###

  def make_pf(type: nil, additions: [], subtractions: [])
    OpenStruct.new(type: type, additions: additions, subtractions: subtractions)
  end

  def make_config(tests: make_pf, mocks: make_pf)
    OpenStruct.new(tests: tests, mocks: mocks)
  end

  context "#extract_implementation_functions" do
    it "returns nil when config tests type is nil" do
      defs = []
      pf   = make_pf

      expect(@partializer_helper).not_to receive(:find_and_transform_func)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, nil, :impl).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to be_nil
    end

    it "delegates initial list to filter_and_transform_funcs for PUBLIC type" do
      defs     = [double('func1', name: 'pub')]
      filtered = [double('impl_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates initial list to filter_and_transform_funcs for PRIVATE type" do
      defs     = [double('func1', name: 'priv')]
      filtered = [double('impl_func')]
      pf       = make_pf(type: Partials::PRIVATE)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PRIVATE, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "fills list from additions only for ACCUMULATE type" do
      defs  = [double('func1', name: 'named')]
      found = double('impl_func', name: 'named')
      pf    = make_pf(type: Partials::ACCUMULATE, additions: ['named'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::ACCUMULATE, :impl).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'named', primary_funcs: defs, secondary_funcs: [], output_type: :impl)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq([found])
    end

    it "adds cross-visibility function from additions to initial list" do
      pub_func  = double('pub',  name: 'pub')
      priv_func = double('priv', name: 'priv')
      defs      = [pub_func, priv_func]
      filtered  = [double('impl_pub', name: 'pub')]
      added     = double('impl_priv', name: 'priv')
      pf        = make_pf(type: Partials::PUBLIC, additions: ['priv'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'priv', primary_funcs: defs, secondary_funcs: [], output_type: :impl)
        .and_return(added)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [filtered[0], added], names: []).and_return([filtered[0], added])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to include(filtered[0], added)
    end

    it "skips addition when function already in initial list (dedup)" do
      func     = double('impl_pub', name: 'pub')
      defs     = [double('def', name: 'pub')]
      filtered = [func]
      pf       = make_pf(type: Partials::PUBLIC, additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).not_to receive(:find_and_transform_func)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates subtractions to subtract_funcs" do
      defs     = [double('func', name: 'pub')]
      filtered = [double('impl_pub', name: 'pub')]
      pf       = make_pf(type: Partials::PUBLIC, subtractions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs, config: make_config(tests: pf)
      )
      expect(result).to eq([])
    end

    it "subtracts mocks.additions from the impl result" do
      defs     = [double('func', name: 'pub')]
      filtered = [double('impl_pub', name: 'pub')]
      test_pf  = make_pf(type: Partials::PUBLIC)
      mock_pf  = make_pf(additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :impl).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])

      result = @partializer.extract_implementation_functions(
        test: 'test_mod', partial: 'mod', definitions: defs,
        config: make_config(tests: test_pf, mocks: mock_pf)
      )
      expect(result).to eq([])
    end
  end

  ###
  ### extract_interface_functions()
  ###

  context "#extract_interface_functions" do
    it "returns nil when config mocks type is nil" do
      defs  = []
      decls = []
      pf    = make_pf

      expect(@partializer_helper).not_to receive(:find_and_transform_func)

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, nil, :interface).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to be_nil
    end

    it "delegates initial list to filter_and_transform_funcs for PUBLIC type" do
      defs     = [double('func1', name: 'pub')]
      decls    = []
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PUBLIC)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates initial list to filter_and_transform_funcs for PRIVATE type" do
      defs     = [double('func1', name: 'priv')]
      decls    = []
      filtered = [double('iface_func')]
      pf       = make_pf(type: Partials::PRIVATE)

      expect(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PRIVATE, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "fills list from additions only for ACCUMULATE type" do
      defs   = [double('def', name: 'named')]
      decls  = []
      found  = double('iface_func', name: 'named')
      pf     = make_pf(type: Partials::ACCUMULATE, additions: ['named'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::ACCUMULATE, :interface).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'named', primary_funcs: defs, secondary_funcs: decls, output_type: :interface)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq([found])
    end

    it "searches definitions then declarations for additions" do
      defs  = []
      decls = [double('decl', name: 'decl_only')]
      found = double('iface_func', name: 'decl_only')
      pf    = make_pf(type: Partials::ACCUMULATE, additions: ['decl_only'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::ACCUMULATE, :interface).and_return([])
      expect(@partializer_helper).to receive(:find_and_transform_func)
        .with(name: 'decl_only', primary_funcs: defs, secondary_funcs: decls, output_type: :interface)
        .and_return(found)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [found], names: []).and_return([found])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to include(found)
    end

    it "skips addition when function already in initial list (dedup)" do
      func     = double('iface_pub', name: 'pub')
      defs     = [double('def', name: 'pub')]
      decls    = []
      filtered = [func]
      pf       = make_pf(type: Partials::PUBLIC, additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      expect(@partializer_helper).not_to receive(:find_and_transform_func)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq(filtered)
    end

    it "delegates subtractions to subtract_funcs" do
      defs     = [double('func', name: 'pub')]
      decls    = []
      filtered = [double('iface_pub', name: 'pub')]
      pf       = make_pf(type: Partials::PUBLIC, subtractions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: [], names: []).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls, config: make_config(mocks: pf)
      )
      expect(result).to eq([])
    end

    it "subtracts tests.additions from the interface result" do
      defs     = [double('func', name: 'pub')]
      decls    = []
      filtered = [double('iface_pub', name: 'pub')]
      mock_pf  = make_pf(type: Partials::PUBLIC)
      test_pf  = make_pf(additions: ['pub'])

      allow(@partializer_helper).to receive(:filter_and_transform_funcs)
        .with(defs, Partials::PUBLIC, :interface).and_return(filtered)
      allow(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: []).and_return(filtered)
      expect(@partializer_helper).to receive(:subtract_funcs)
        .with(funcs: filtered, names: ['pub']).and_return([])

      result = @partializer.extract_interface_functions(
        test: 'test_mod', partial: 'mod',
        definitions: defs, declarations: decls,
        config: make_config(tests: test_pf, mocks: mock_pf)
      )
      expect(result).to eq([])
    end
  end

end