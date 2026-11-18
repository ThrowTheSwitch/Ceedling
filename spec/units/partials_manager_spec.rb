# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/partials_manager'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_config'
require 'ceedling/includes/includes'

describe PartialsManager do
  before(:each) do
    @configurator     = double( "Configurator" )
    @loginator        = double( "Loginator" )
    @reportinator     = double( "Reportinator" )
    @batchinator      = double( "Batchinator" )
    @partializer      = double( "Partializer" )
    @generator        = double( "Generator" )
    @dependinator     = double( "Dependinator" )
    @file_path_utils  = double( "FilePathUtils" )
    @file_wrapper     = double( "FileWrapper" )
    @mock_locator     = double( "MockLocator" )
    @header_search    = double( "HeaderSearch" )

    allow(@mock_locator).to receive(:header_search).and_return( @header_search )
    allow(@header_search).to receive(:spelled) { |include| include }

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)

    @partials_config = { max_extraction_length: 5000 }

    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@configurator).to receive(:get_partials_config).and_return( @partials_config )

    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)
    allow(@file_wrapper).to receive(:exist?).and_return( false )

    @manager = described_class.new(
      {
        :configurator     => @configurator,
        :loginator        => @loginator,
        :reportinator     => @reportinator,
        :batchinator      => @batchinator,
        :partializer      => @partializer,
        :generator        => @generator,
        :dependinator     => @dependinator,
        :file_path_utils  => @file_path_utils,
        :file_wrapper     => @file_wrapper,
        :mock_locator     => @mock_locator
      }
    )
  end

  # `@batchinator.exec` is a real collaborator only in production; here it's
  # stubbed to synchronously yield every `things` entry to the given block,
  # matching its real per-item iteration contract without pulling in Parallel.
  def stub_batchinator_exec
    allow(@batchinator).to receive(:exec) do |things:, **, &block|
      things.each { |k, v| block.call(k, v) }
    end
  end

  context "#stage_generate_partials" do
    before(:each) do
      stub_batchinator_exec()

      @module_contents = double( "CModule",
        function_definitions:    [],
        function_declarations:   [],
        type_definitions:        [],
        aggregate_definitions:   []
      )
      # Whether the module has types follows from its lists, which an example may stub
      allow(@module_contents).to receive(:types?) { !(@module_contents.type_definitions.empty? and @module_contents.aggregate_definitions.empty?) }
      allow(@partializer).to receive(:extract_module_contents).and_return( @module_contents )
      allow(@partializer).to receive(:validate_config)
      allow(@partializer).to receive(:sanitize)
      allow(@partializer).to receive(:validate_extracted_functions)
      allow(@partializer).to receive(:remap_implementation_header_includes).and_return( Partials::IncludeGroups.new )
      allow(@partializer).to receive(:remap_implementation_source_includes).and_return( [] )
      allow(@partializer).to receive(:remap_interface_header_includes).and_return( Partials::IncludeGroups.new )
      allow(@partializer).to receive(:remap_types_header_includes).and_return( Partials::IncludeGroups.new )
      allow(@partializer).to receive(:extract_module_include_guard).and_return( 'FOO_H' )
      allow(@partializer).to receive(:plan_carry).and_return( Partials::CarryPlan.new )
      allow(@partializer).to receive(:plan_interface_extras).and_return( Partials::InterfaceExtras.new )
      allow(@partializer).to receive(:explain_tested_mock)
      allow(@configurator).to receive(:partials_suppress_redundant_decls).and_return( true )
      allow(@configurator).to receive(:partials_extern_variables).and_return( :weak )
      allow(@generator).to receive(:generate_partial_types)
      allow(@generator).to receive(:generate_partial_implementation)
      allow(@generator).to receive(:generate_partial_interface)

      allow(@file_path_utils).to receive(:form_partial_types_header_filename).and_return( 'ceedling_partial_Foo_types.h' )
      allow(@file_path_utils).to receive(:form_partial_implementation_source_filename).and_return( 'ceedling_partial_Foo_impl.c' )
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename).and_return( 'ceedling_partial_Foo_impl.h' )
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename).and_return( 'ceedling_partial_Foo_interface.h' )
      allow(@file_path_utils).to receive(:form_partial_extras_header_filename).and_return( 'ceedling_partial_Foo_extras.h' )

      allow(@dependinator).to receive(:register)
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@dependinator).to receive(:mark_fresh)

      @config = PartializerConfig::Config.new(
        module: 'Foo',
        header: Partials::ConfigFileInfo.new( filepath: 'src/Foo.h', includes: [] ),
        source: Partials::ConfigFileInfo.new( filepath: 'src/Foo.c', includes: [] )
      )
      @testable = TestInvokerTypes::Testable.new(
        :name  => 'a_test',
        :paths => { :partials => 'build/test/partials/a_test' }
      )
      @testable.partials.configs = { 'Foo' => @config }
      @state = TestInvokerTypes::PipelineState.new(
        :testables => { :a_test => @testable }, :context => :test, :options => [], :lock => Mutex.new
      )
    end

    # `config` here looks exactly as it would whether stage 6/7 just freshly
    # preprocessed it or recalled it whole from a dependency-tracker cache
    # hit -- this stage reads only `config` and has no way to tell the
    # difference, so a single fixture covers both cases.
    it "adds the module to tests and mocks when both implementation and interface are extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      @manager.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( ['Foo'] )
      expect( @testable.partials.mocks ).to eq( ['Foo'] )
    end

    # Build threads finish in any order, and a test's link records its objects in order
    it "keeps a test's Partial modules in configuration order, however the batch finishes" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@batchinator).to receive(:exec) do |things:, **, &block|
        things.reverse_each { |thing| block.call( thing ) }
      end
      @testable.partials.configs = %w[Alpha Beta Gamma].to_h do |name|
        [name, PartializerConfig::Config.new( module: name, header: @config.header, source: @config.source )]
      end

      @manager.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( %w[Alpha Beta Gamma] )
      expect( @testable.partials.mocks ).to eq( %w[Alpha Beta Gamma] )
    end

    it "plans what the implementation carries from both selections, the Partial and the guard" do
      impl  = [double("FunctionDefinition")]
      iface = [double("FunctionDeclaration")]
      allow(@partializer).to receive(:extract_implementation_functions).and_return( impl )
      allow(@partializer).to receive(:extract_interface_functions).and_return( iface )

      expect(@partializer).to receive(:plan_carry).with(
        test: 'a_test', c_module: @module_contents, impl: impl, interface: iface, header_guarded: true, config: @config
      ).and_return( Partials::CarryPlan.new )

      @manager.stage_generate_partials( @state )
    end

    # Without a guard to stand in for, the real header may arrive through another include
    it "plans for an unguarded module header when the header has no guard" do
      allow(@partializer).to receive(:extract_module_include_guard).and_return( nil )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )

      expect(@partializer).to receive(:plan_carry).with( hash_including( header_guarded: false ) ).and_return( Partials::CarryPlan.new )

      @manager.stage_generate_partials( @state )
    end

    it "hands the plan and both Partials settings to implementation generation" do
      plan = Partials::CarryPlan.new
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )
      allow(@partializer).to receive(:plan_carry).and_return( plan )
      allow(@configurator).to receive(:partials_suppress_redundant_decls).and_return( false )
      allow(@configurator).to receive(:partials_extern_variables).and_return( :test )

      expect(@generator).to receive(:generate_partial_implementation).with(
        hash_including( carry: plan, suppress_redundant_decls: false, extern_variables: :test )
      )

      @manager.stage_generate_partials( @state )
    end

    # Only a regenerating implementation reads the plan, so its notices appear with that build
    it "plans nothing when only the interface regenerates" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@dependinator).to receive(:stale?) { |target| target.end_with?( 'ceedling_partial_Foo_interface.h' ) }

      expect(@partializer).not_to receive(:plan_carry)
      expect(@generator).to receive(:generate_partial_interface)

      @manager.stage_generate_partials( @state )
    end

    it "plans nothing when no implementation is extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@partializer).not_to receive(:plan_carry)

      @manager.stage_generate_partials( @state )
    end

    # A mock-only Partial's interface stands in for the real header, so it keeps the rest of it
    it "plans what a mock-only Partial's interface keeps from the module, its selection and the guard" do
      interface = [double("FunctionDeclaration")]
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( interface )

      expect(@partializer).to receive(:plan_interface_extras).with(
        test: 'a_test', c_module: @module_contents, interface: interface, header_guarded: true, config: @config
      ).and_return( Partials::InterfaceExtras.new )

      @manager.stage_generate_partials( @state )
    end

    # The module's implementation carries what its own code uses
    it "plans no extras for a module the test also tests" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@partializer).not_to receive(:plan_interface_extras)
      expect(@generator).to receive(:generate_partial_interface).with( hash_including( extras: nil ) )

      @manager.stage_generate_partials( @state )
    end

    it "explains what other Partials go without when the test both tests and mocks a module" do
      interface = [double("FunctionDeclaration")]
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( interface )

      expect(@partializer).to receive(:explain_tested_mock).with(
        test: 'a_test', c_module: @module_contents, interface: interface, header_guarded: true, config: @config,
        partials: @testable.partials.configs
      )

      @manager.stage_generate_partials( @state )
    end

    it "explains nothing for a mock-only Partial" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@partializer).not_to receive(:explain_tested_mock)

      @manager.stage_generate_partials( @state )
    end

    it "hands the extras to interface generation, which vouches for the extras header" do
      extras = Partials::InterfaceExtras.new( items: [double("CFunctionDefinition")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@partializer).to receive(:plan_interface_extras).and_return( extras )

      expect(@generator).to receive(:generate_partial_interface).with( hash_including( extras: extras ) )

      @manager.stage_generate_partials( @state )

      expect(@dependinator).to have_received(:register).with(
        'build/test/partials/a_test/ceedling_partial_Foo_interface.h',
        hash_including( outputs: ['build/test/partials/a_test/ceedling_partial_Foo_extras.h'] )
      )
    end

    # An extras header an earlier build left would sit beside an interface that no longer includes it
    it "removes an extras header an earlier build left once the interface keeps nothing" do
      extras = 'build/test/partials/a_test/ceedling_partial_Foo_extras.h'
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@file_wrapper).to receive(:exist?).with( extras ).and_return( true )

      expect(@file_wrapper).to receive(:rm_f).with( extras )

      @manager.stage_generate_partials( @state )
    end

    it "does not add to tests when no implementation is extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      @manager.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( [] )
      expect( @testable.partials.mocks ).to eq( ['Foo'] )
    end

    it "does not add to mocks when no interface is extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )

      @manager.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( ['Foo'] )
      expect( @testable.partials.mocks ).to eq( [] )
    end

    it "skips writing types, implementation, and interface when the dependency tracker reports all three unchanged, but still updates tests/mocks bookkeeping" do
      @config.tests = PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC )
      @config.mocks = PartializerConfig::PartialFunctions.new( type: Partials::PRIVATE )
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@generator).to_not receive(:generate_partial_types)
      expect(@generator).to_not receive(:generate_partial_implementation)
      expect(@generator).to_not receive(:generate_partial_interface)
      expect(@dependinator).to_not receive(:mark_fresh)

      @manager.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( ['Foo'] )
      expect( @testable.partials.mocks ).to eq( ['Foo'] )
    end

    # The same call writes the implementation header, so the source vouches for it
    it "registers the implementation header as an output of the implementation source" do
      allow(@module_contents).to receive(:type_definitions).and_return( [] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      @manager.stage_generate_partials( @state )

      expect(@dependinator).to have_received(:register).with(
        'build/test/partials/a_test/ceedling_partial_Foo_impl.c',
        hash_including( outputs: ['build/test/partials/a_test/ceedling_partial_Foo_impl.h'] )
      )
    end

    # Both include the types header, so each vouches for it
    it "registers the types header as an output of both the implementation and the interface" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      @manager.stage_generate_partials( @state )

      types = 'build/test/partials/a_test/ceedling_partial_Foo_types.h'
      expect(@dependinator).to have_received(:register).with(
        'build/test/partials/a_test/ceedling_partial_Foo_impl.c',
        hash_including( outputs: ['build/test/partials/a_test/ceedling_partial_Foo_impl.h', types] )
      )
      expect(@dependinator).to have_received(:register).with(
        'build/test/partials/a_test/ceedling_partial_Foo_interface.h', hash_including( outputs: [types] )
      )
    end

    # Whether a types header exists follows from the module files the record already holds, so
    # the record can be known before extraction while generation still includes the header
    it "records include lists without the types header and still generates with it" do
      types_include = UserInclude.new( 'ceedling_partial_Foo_types.h' )
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      [:remap_implementation_header_includes, :remap_interface_header_includes].each do |remap|
        allow(@partializer).to receive(remap) do |types_header: nil, **|
          Partials::IncludeGroups.new( leading: [types_header && types_include, UserInclude.new( 'dep.h' )].compact )
        end
      end

      metas = []
      allow(@dependinator).to receive(:register) { |_target, meta: {}, **| metas << meta }
      expect(@generator).to receive(:generate_partial_implementation).with( hash_including( header_includes: [types_include, UserInclude.new( 'dep.h' )] ) )
      expect(@generator).to receive(:generate_partial_interface).with( hash_including( includes: [types_include, UserInclude.new( 'dep.h' )] ) )

      @manager.stage_generate_partials( @state )

      recorded = { leading: ['#include "dep.h"'], following: [] }
      expect( metas.map { |meta| meta.values_at( :impl_header_includes, :interface_includes ) }.uniq ).to eq( [[recorded, recorded]] )
    end

    it "registers the whole :partials config as meta, and an empty tools list since this stage runs no shell tool" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, meta: {}, **|
        expect( meta[:tools] ).to eq( [] )
        expect( meta[:partials] ).to eq( @partials_config )
      end

      @manager.stage_generate_partials( @state )
    end

    # The guard and the carried include list are inputs to generation, so a change to either has
    # to invalidate what was generated from the previous ones. Omitting them would leave an
    # incremental build serving a stale types header.
    it "registers the guard and the carried include list as meta" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@partializer).to receive(:remap_types_header_includes)
        .and_return( Partials::IncludeGroups.new( leading: [UserInclude.new('foundation.h')], following: [UserInclude.new('log.h')] ) )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, meta: {}, **|
        expect( meta[:include_guard] ).to eq( 'FOO_H' )
        expect( meta[:types_includes] ).to eq( { leading: ['#include "foundation.h"'], following: ['#include "log.h"'] } )
      end

      @manager.stage_generate_partials( @state )
    end

    # What a test selects decides what is generated, so switching TEST_PARTIAL_PUBLIC_MODULE to
    # TEST_PARTIAL_ALL_MODULE, or adding a function, has to regenerate the Partial.
    it "registers the module's selection, both sides, as meta" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      @config.tests = PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC, additions: ['bar'] )
      @config.mocks = PartializerConfig::PartialFunctions.new( type: Partials::PRIVATE, subtractions: ['baz'] )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, meta: {}, **|
        expect( meta[:selection] ).to eq(
          tests: { type: Partials::PUBLIC, additions: ['bar'], subtractions: [] },
          mocks: { type: Partials::PRIVATE, additions: [], subtractions: ['baz'] }
        )
      end

      @manager.stage_generate_partials( @state )
    end

    it "registers different meta for selections that differ only in mode or additions" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )

      metas = []
      allow(@dependinator).to receive(:register) { |_target, meta: {}, **| metas << meta }

      [
        PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC ),
        PartializerConfig::PartialFunctions.new( type: Partials::DEDUCT ),
        PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC, additions: ['helper'] )
      ].each do |tests|
        @config.tests = tests
        @manager.stage_generate_partials( @state )
      end

      expect( metas.uniq.length ).to eq( 3 )
    end

    # Each generated file's includes depend on the test's other Partial modules and how each is
    # selected, so a change to any of those lists has to regenerate.
    it "registers every generated file's include list as meta" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@partializer).to receive(:remap_types_header_includes).and_return( Partials::IncludeGroups.new( leading: [UserInclude.new('types_dep.h')] ) )
      allow(@partializer).to receive(:remap_implementation_header_includes).and_return( Partials::IncludeGroups.new( following: [UserInclude.new('impl_h_dep.h')] ) )
      allow(@partializer).to receive(:remap_implementation_source_includes).and_return( [UserInclude.new('impl_c_dep.h')] )
      allow(@partializer).to receive(:remap_interface_header_includes).and_return( Partials::IncludeGroups.new( leading: [UserInclude.new('interface_dep.h')] ) )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, meta: {}, **|
        expect( meta[:types_includes] ).to eq( { leading: ['#include "types_dep.h"'], following: [] } )
        expect( meta[:impl_header_includes] ).to eq( { leading: [], following: ['#include "impl_h_dep.h"'] } )
        expect( meta[:impl_source_includes] ).to eq( ['#include "impl_c_dep.h"'] )
        expect( meta[:interface_includes] ).to eq( { leading: ['#include "interface_dep.h"'], following: [] } )
      end

      @manager.stage_generate_partials( @state )
    end

    # Remapping logs each list it computes for a named test, so generation's lists are the only ones named
    it "computes generation's include lists once, logged under the test's name, and hands them to generation" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      impl_h    = Partials::IncludeGroups.new( leading: [UserInclude.new('impl_h_dep.h')], following: [UserInclude.new('impl_h_later.h')] )
      impl_c    = [UserInclude.new('impl_c_dep.h')]
      interface = Partials::IncludeGroups.new( leading: [UserInclude.new('interface_dep.h')], following: [UserInclude.new('interface_later.h')] )
      expect(@partializer).to receive(:remap_implementation_header_includes).with( hash_including( test: 'a_test' ) ).once.and_return( impl_h )
      expect(@partializer).to receive(:remap_implementation_source_includes).with( hash_including( test: 'a_test' ) ).once.and_return( impl_c )
      expect(@partializer).to receive(:remap_interface_header_includes).with( hash_including( test: 'a_test' ) ).once.and_return( interface )
      expect(@partializer).to receive(:remap_types_header_includes).with( hash_including( test: 'a_test' ) ).once.and_return( Partials::IncludeGroups.new )

      expect(@generator).to receive(:generate_partial_implementation).with(
        hash_including( header_includes: impl_h.leading, header_following_includes: impl_h.following, source_includes: impl_c )
      )
      expect(@generator).to receive(:generate_partial_interface).with(
        hash_including( includes: interface.leading, following_includes: interface.following )
      )

      @manager.stage_generate_partials( @state )
    end

    # A generated header's includes split where the source includes the module's header, so the
    # header remaps need the two lists apart. The implementation source keeps one list.
    it "hands the header remaps the source's and the header's includes apart" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      @config.source.includes = [UserInclude.new( 'Foo.h' ), UserInclude.new( 'log.h' )]
      @config.header.includes = [UserInclude.new( 'base.h' )]
      apart = hash_including( source_includes: @config.source.includes, header_includes: @config.header.includes )

      %i[remap_types_header_includes remap_implementation_header_includes remap_interface_header_includes].each do |remap|
        expect(@partializer).to receive(remap).with( apart ).twice.and_return( Partials::IncludeGroups.new )
      end
      expect(@partializer).to receive(:remap_implementation_source_includes)
        .with( hash_including( includes: @config.source.includes + @config.header.includes ) ).twice.and_return( [] )

      @manager.stage_generate_partials( @state )
    end

    # A generated file writes each #include by the text the test's search paths reach its header by
    it "hands the remaps each include spelled as the test's search paths reach its header" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      written = UserInclude.new( 'drivers/foo.h' )
      spelled = UserInclude.new( 'src/drivers/foo.h', include_path: 'drivers/foo.h' )
      @config.source.includes = [written]
      allow(@header_search).to receive(:spelled).with( written ).and_return( spelled )

      expect(@partializer).to receive(:remap_types_header_includes)
        .with( hash_including( source_includes: [spelled] ) ).twice.and_return( Partials::IncludeGroups.new )
      expect(@partializer).to receive(:remap_implementation_source_includes)
        .with( hash_including( includes: [spelled] ) ).twice.and_return( [] )

      @manager.stage_generate_partials( @state )
    end

    it "searches once per test, however many Partials it holds" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      @testable.partials.configs = { 'Foo' => @config, 'Bar' => @config.dup.tap { |c| c.module = 'Bar' } }

      expect(@mock_locator).to receive(:header_search).with( @testable ).once.and_return( @header_search )

      @manager.stage_generate_partials( @state )
    end

    it "computes the record's include lists without a test name, so nothing logs them" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      %i[remap_types_header_includes remap_implementation_header_includes remap_implementation_source_includes remap_interface_header_includes].each do |remap|
        result = (remap == :remap_implementation_source_includes) ? [] : Partials::IncludeGroups.new
        expect(@partializer).to receive(remap).with( hash_including( test: nil ) ).once.and_return( result )
      end

      @manager.stage_generate_partials( @state )
    end

    # Generation reads the preprocessed copies, not the originals. A change that rewrites the
    # copies without touching the originals -- forced fallback toggled, a different
    # preprocessor -- has to regenerate.
    it "registers the preprocessed copies generation reads as antecedent files" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      @config.header.assembled_filepath = 'build/pp/src/Foo.h'
      @config.header.expansion_filepath = 'build/pp/expanded_code/src/Foo.h'
      @config.source.assembled_filepath = 'build/pp/src/Foo.c'
      @config.source.expansion_filepath = 'build/pp/expanded_code/src/Foo.c'
      @config.header.raw_directives_only_filepath = 'build/pp/directives_only/raw/src/Foo.h'

      expect(@dependinator).to receive(:register).exactly(3).times do |_target, files: [], **|
        expect( files ).to contain_exactly(
          'src/Foo.h', 'src/Foo.c',
          'build/pp/src/Foo.h', 'build/pp/expanded_code/src/Foo.h',
          'build/pp/src/Foo.c', 'build/pp/expanded_code/src/Foo.c', 'build/pp/directives_only/raw/src/Foo.h'
        )
      end

      @manager.stage_generate_partials( @state )
    end

    it "hands the guard and the carried include list to types generation" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      carried = Partials::IncludeGroups.new( leading: [UserInclude.new('foundation.h')], following: [UserInclude.new('log.h')] )
      allow(@partializer).to receive(:remap_types_header_includes).and_return( carried )

      expect(@generator).to receive(:generate_partial_types).with(
        hash_including( includes: carried.leading, following_includes: carried.following, include_guard: 'FOO_H' )
      )

      @manager.stage_generate_partials( @state )
    end

    # A module with no types gets no types header, so the implementation and interface headers
    # have to state the guard themselves or nothing suppresses the real header.
    it "hands the guard to implementation and interface generation too" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@generator).to receive(:generate_partial_implementation).with(
        hash_including( include_guard: 'FOO_H' )
      )
      expect(@generator).to receive(:generate_partial_interface).with(
        hash_including( include_guard: 'FOO_H' )
      )

      @manager.stage_generate_partials( @state )
    end

    # Every generated file states the guard, so extraction's copy of it is removed
    it "hands the guard to sanitizing the extracted module" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      expect(@partializer).to receive(:sanitize).with( @module_contents, include_guard: 'FOO_H' )

      @manager.stage_generate_partials( @state )
    end

    it "reads the guard from the module's own header" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      expect(@partializer).to receive(:extract_module_include_guard).with( 'src/Foo.h' )

      @manager.stage_generate_partials( @state )
    end

    # Fallback resolves strictly less than the accurate pass, and validate_config refuses the
    # shapes it cannot handle. The Partial's own files record which path ran.
    it "hands config validation the Partial whose files record how they were preprocessed" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      expect(@partializer).to receive(:validate_config).with( c_module: @module_contents, config: @config, name: 'a_test' )

      @manager.stage_generate_partials( @state )
    end

    it "never registers or checks a types-header target when the module has no type or aggregate definitions" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      expect(@dependinator).to_not receive(:register).with( /_types\.h$/, any_args )
      expect(@generator).to_not receive(:generate_partial_types)

      @manager.stage_generate_partials( @state )
    end

    it "never passes a nil filepath to the dependency tracker when a Partial has no paired source file" do
      # A declaration-only Partial (a prototype with no matching .c definition) has
      # no source file to find -- config.source.filepath legitimately stays nil.
      @config.source = Partials::ConfigFileInfo.new( filepath: nil, includes: [] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, files: [], **|
        expect( files ).to_not include( nil )
      end

      @manager.stage_generate_partials( @state )
    end

    # Generated files that are all fresh already hold what extraction would produce
    context "when the implementation and interface are both fresh" do
      before(:each) do
        @config.tests = PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC )
        @config.mocks = PartializerConfig::PartialFunctions.new( type: Partials::PRIVATE )
        allow(@dependinator).to receive(:stale?).and_return( false )
      end

      it "extracts nothing, yet adds the module to tests and mocks" do
        expect(@partializer).not_to receive(:extract_module_contents)
        expect(@partializer).not_to receive(:validate_config)
        expect(@generator).not_to receive(:generate_partial_implementation)

        @manager.stage_generate_partials( @state )

        expect( @testable.partials.tests ).to eq( ['Foo'] )
        expect( @testable.partials.mocks ).to eq( ['Foo'] )
      end

      it "adds the module only to the list its selection names" do
        @config.mocks = PartializerConfig::PartialFunctions.new

        @manager.stage_generate_partials( @state )

        expect( @testable.partials.tests ).to eq( ['Foo'] )
        expect( @testable.partials.mocks ).to eq( [] )
      end

      # A module mocked from its header alone has only an interface to vouch for it
      it "skips a mock-only Partial on its interface alone" do
        @config.tests = PartializerConfig::PartialFunctions.new

        expect(@partializer).not_to receive(:extract_module_contents)
        expect(@reportinator).not_to receive(:generate_module_progress).with( hash_including( operation: "Skipping Partial implementation generation for" ) )

        @manager.stage_generate_partials( @state )

        expect( @testable.partials.tests ).to eq( [] )
        expect( @testable.partials.mocks ).to eq( ['Foo'] )
      end

      # A full run prunes the record of any target it never registers
      it "registers a types header still on disk, so its record survives" do
        types = 'build/test/partials/a_test/ceedling_partial_Foo_types.h'
        allow(@file_wrapper).to receive(:exist?).with( types ).and_return( true )

        @manager.stage_generate_partials( @state )

        expect(@dependinator).to have_received(:register).with( types, hash_including( :files, :meta ) )
      end

      # The implementation and interface vouch for the types header they include
      it "leaves the types header's own record out of the decision" do
        types = 'build/test/partials/a_test/ceedling_partial_Foo_types.h'
        allow(@file_wrapper).to receive(:exist?).with( types ).and_return( true )
        allow(@dependinator).to receive(:stale?) { |target| target == types }

        expect(@partializer).not_to receive(:extract_module_contents)

        @manager.stage_generate_partials( @state )
      end

      it "logs a skip line and counts a skip for each file it would have generated" do
        allow(@file_wrapper).to receive(:exist?).and_return( true )
        %w[types implementation interface].each do |kind|
          expect(@reportinator).to receive(:generate_module_progress)
            .with( hash_including( operation: "Skipping Partial #{kind} generation for" ) ).and_return( '' )
        end
        [
          ['Partial types generation', 'types headers'],
          ['Partial implementation generation', 'implementations'],
          ['Partial interface generation', 'interfaces']
        ].each do |task, noun|
          expect(@reportinator).to receive(:generate_skip_summary).with( hash_including( task: task, count: 1, noun: noun ) )
        end

        @manager.stage_generate_partials( @state )
      end

      it "extracts and generates when the interface alone is stale" do
        allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
        allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
        allow(@dependinator).to receive(:stale?) { |target| target.end_with?( '_interface.h' ) }

        expect(@partializer).to receive(:extract_module_contents).and_return( @module_contents )
        expect(@generator).to receive(:generate_partial_interface)

        @manager.stage_generate_partials( @state )
      end
    end

    # A types header an earlier build left would pass for current whenever the Partial is next fresh
    it "removes a types header an earlier build left once the module has no types" do
      types = 'build/test/partials/a_test/ceedling_partial_Foo_types.h'
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@file_wrapper).to receive(:exist?).with( types ).and_return( true )

      expect(@file_wrapper).to receive(:rm_f).with( types )
      expect(@dependinator).to receive(:invalidate).with( types )

      @manager.stage_generate_partials( @state )
    end

    it "keeps the types header of a module that still has types" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@file_wrapper).to receive(:rm_f)

      @manager.stage_generate_partials( @state )

      expect(@file_wrapper).not_to have_received(:rm_f).with( 'build/test/partials/a_test/ceedling_partial_Foo_types.h' )
    end

    # Nothing else can vouch for what the module's files would generate
    it "extracts a Partial whose selection names neither an implementation nor an interface" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@partializer).to receive(:extract_module_contents).and_return( @module_contents )

      @manager.stage_generate_partials( @state )
    end

    it "logs summary lines stating how many of each Partial artifact were recalled from cache" do
      @config.tests = PartializerConfig::PartialFunctions.new( type: Partials::PUBLIC )
      @config.mocks = PartializerConfig::PartialFunctions.new( type: Partials::PRIVATE )
      allow(@file_wrapper).to receive(:exist?).and_return( true )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping ... (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping ... (nothing changed)..." ).exactly(3).times

      @manager.stage_generate_partials( @state )
    end
  end

end
