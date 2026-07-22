# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_build_executor'
require 'ceedling/test_invoker/test_invoker_types'

PROJECT_BUILD_VENDOR_UNITY_PATH = 'build/vendor/unity' unless defined?(PROJECT_BUILD_VENDOR_UNITY_PATH)
UNITY_C_FILE = 'unity.c' unless defined?(UNITY_C_FILE)

describe TestBuildExecutor do
  before(:each) do
    @configurator            = double( "Configurator" )
    @loginator                = double( "Loginator" )
    @reportinator               = double( "Reportinator" )
    @batchinator                  = double( "Batchinator" )
    @preprocessinator                = double( "Preprocessinator" )
    @partializer                       = double( "Partializer" )
    @generator                           = double( "Generator" )
    @test_context_extractor                 = double( "TestContextExtractor" )
    @plugin_manager                            = double( "PluginManager" )
    @file_path_utils                              = double( "FilePathUtils" )
    @file_finder                                     = double( "FileFinder" )
    @file_wrapper                                       = double( "FileWrapper" )

    @tools_test_compiler  = { name: 'fake compiler' }
    @tools_test_assembler = { name: 'fake assembler' }

    allow(@configurator).to receive(:extension_assembly).and_return( '.asm' )
    allow(@configurator).to receive(:tools_test_compiler).and_return( @tools_test_compiler )
    allow(@configurator).to receive(:tools_test_assembler).and_return( @tools_test_assembler )
    allow(@configurator).to receive(:project_use_mocks).and_return( false )
    allow(@configurator).to receive(:project_use_exceptions).and_return( false )
    allow(@configurator).to receive(:collection_all_support).and_return( [] )

    allow(@file_path_utils).to receive(:form_test_build_list_filepath).and_return( 'build/list' )
    allow(@file_path_utils).to receive(:form_test_dependencies_filepath).and_return( 'build/deps' )

    @executor = described_class.new(
      {
        :configurator            => @configurator,
        :loginator               => @loginator,
        :reportinator            => @reportinator,
        :batchinator             => @batchinator,
        :preprocessinator        => @preprocessinator,
        :partializer             => @partializer,
        :generator               => @generator,
        :test_context_extractor  => @test_context_extractor,
        :plugin_manager          => @plugin_manager,
        :file_path_utils         => @file_path_utils,
        :file_finder             => @file_finder,
        :file_wrapper            => @file_wrapper
      }
    )

    testable = TestInvokerTypes::Testable.new(
      :compile_defines  => [],
      :search_paths     => [],
      :compile_flags    => [],
      :assembler_flags  => []
    )

    @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => testable } )
  end

  context "#compile_test_component" do
    it "compiles a C source file with the configured test compiler tool" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )

      expect(@generator).to receive(:generate_object_file_c) do |**args|
        expect( args[:tool] ).to eq( @tools_test_compiler )
      end
      expect(@generator).to_not receive(:generate_object_file_asm)

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.c', :object => 'build/foo.o', :state => @state
      )
    end

    it "assembles an assembly source file with the configured test assembler tool when assembly support is enabled" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.asm' ).and_return( '.asm' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( true )

      expect(@generator).to receive(:generate_object_file_asm) do |**args|
        expect( args[:tool] ).to eq( @tools_test_assembler )
      end
      expect(@generator).to_not receive(:generate_object_file_c)

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.asm', :object => 'build/foo.o', :state => @state
      )
    end

    it "does not compile an assembly source file when assembly support is disabled" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.asm' ).and_return( '.asm' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )

      expect(@generator).to_not receive(:generate_object_file_c)
      expect(@generator).to_not receive(:generate_object_file_asm)

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.asm', :object => 'build/foo.o', :state => @state
      )
    end
  end
end
