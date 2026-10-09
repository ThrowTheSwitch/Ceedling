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
require 'ceedling/includes/includes'

describe PartialsManager do
  before(:each) do
    @configurator     = double( "Configurator" )
    @loginator        = double( "Loginator" )
    @reportinator     = double( "Reportinator" )
    @batchinator      = double( "Batchinator" )
    @preprocessinator = double( "Preprocessinator" )
    @partializer      = double( "Partializer" )
    @generator        = double( "Generator" )
    @dependinator     = double( "Dependinator" )
    @file_path_utils  = double( "FilePathUtils" )

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)

    @tools_test_bare_includes_preprocessor        = { name: 'fake bare includes preprocessor' }
    @tools_test_file_directives_only_preprocessor = { name: 'fake directives-only preprocessor' }
    @tools_test_file_full_preprocessor            = { name: 'fake full preprocessor' }
    @partials_config                              = { max_extraction_length: 5000 }

    allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return( @tools_test_bare_includes_preprocessor )
    allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return( @tools_test_file_directives_only_preprocessor )
    allow(@configurator).to receive(:tools_test_file_full_preprocessor).and_return( @tools_test_file_full_preprocessor )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@configurator).to receive(:get_partials_config).and_return( @partials_config )

    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)

    @manager = described_class.new(
      {
        :configurator     => @configurator,
        :loginator        => @loginator,
        :reportinator     => @reportinator,
        :batchinator      => @batchinator,
        :preprocessinator => @preprocessinator,
        :partializer      => @partializer,
        :generator        => @generator,
        :dependinator     => @dependinator,
        :file_path_utils  => @file_path_utils
      }
    )
  end

  # `@batchinator.exec` is a real collaborator only in production; here it's
  # stubbed to synchronously yield every `things` entry to the given block,
  # matching its real per-item iteration contract without pulling in Parallel.
  def stub_batchinator_exec
    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |k, v| block.call(k, v) }
    end
  end

  context "#stage_preprocess_partial_headers" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/Foo.h' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath).and_return( 'build/preprocess/full_expansion/Foo.h' )
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return( 'build/preprocess/includes/Foo.h.yml' )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.h' )
      allow(@preprocessinator).to receive(:preprocess_partial_header_file_preserve_macros).and_return( ['build/preprocess/raw/Foo.h', []] )
      allow(@preprocessinator).to receive(:preprocess_partial_header_expand_macros).and_return( 'build/preprocess/full_expansion/Foo.h' )
      allow(@preprocessinator).to receive(:load_includes_list).and_return( [] )

      @testable = TestInvokerTypes::Testable.new(
        :name               => 'a_test',
        :preprocess_flags   => ['-Wall'], :preprocess_defines => ['TEST'], :search_paths => ['src']
      )
      @config = Partials::ConfigFileInfo.new( filepath: 'src/Foo.h' )
      @details = TestInvokerTypes::PartialWork.new( :config => @config, :testable => @testable, :directives_only_filepath => nil )
      @state = TestInvokerTypes::PipelineState.new(
        :testables => { :a_test => @testable }, :partials_headers => [@details], :context => :test, :options => []
      )
    end

    it "registers the header's deterministic target with the header file as sole antecedent and preprocess flags/defines/search paths, preprocessing tools, and :partials config as meta" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/Foo.h',
        files: ['src/Foo.h'],
        meta:  {
          flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'],
          tools: [@tools_test_file_directives_only_preprocessor, @tools_test_bare_includes_preprocessor, @tools_test_file_full_preprocessor],
          preprocess_force_fallback: false,
          partials: @partials_config
        }
      )

      @manager.stage_preprocess_partial_headers( @state )
    end

    it "runs all three preprocessing passes and marks the target fresh once, at the end, when the dependency tracker reports it stale" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to receive(:generate_directives_only_output).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_header_file_preserve_macros).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_header_expand_macros).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/Foo.h').ordered

      @manager.stage_preprocess_partial_headers( @state )
    end

    # A skipped run recalls both, so the preprocessed target vouches for them
    it "registers the includes list and full expansion as outputs before marking the target fresh" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_partial_header_file_preserve_macros)
      allow(@preprocessinator).to receive(:preprocess_partial_header_expand_macros)

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/Foo.h', outputs: ['build/preprocess/includes/Foo.h.yml', 'build/preprocess/full_expansion/Foo.h']
      ).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/Foo.h').ordered

      @manager.stage_preprocess_partial_headers( @state )
    end

    it "skips all three preprocessing passes and reconstructs config state from the deterministic paths and cached includes list when the dependency tracker reports it unchanged" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( false )
      cached_includes = [ double("Include") ]
      allow(@preprocessinator).to receive(:load_includes_list).with( test: 'a_test', filepath: 'src/Foo.h' ).and_return( cached_includes )

      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to_not receive(:preprocess_partial_header_file_preserve_macros)
      expect(@preprocessinator).to_not receive(:preprocess_partial_header_expand_macros)
      expect(@dependinator).to_not receive(:mark_fresh)

      @manager.stage_preprocess_partial_headers( @state )

      expect( @config.directives_only_filepath ).to eq( 'build/preprocess/Foo.h' )
      expect( @config.includes ).to eq( cached_includes )
      expect( @config.full_expansion_filepath ).to eq( 'build/preprocess/full_expansion/Foo.h' )
    end

    it "does nothing for the directives-only pass when directives-only preprocessing is unavailable for this toolchain, but still runs preserve-macros and full-expansion" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to receive(:preprocess_partial_header_file_preserve_macros)
      expect(@preprocessinator).to receive(:preprocess_partial_header_expand_macros)

      @manager.stage_preprocess_partial_headers( @state )
    end

    it "logs a NORMAL progress line for a header that needs preprocessing, and no OBNOXIOUS skip line" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@reportinator).to receive(:generate_module_progress)
        .with( operation: 'Preprocessing partial header for', module_name: 'a_test', filename: 'Foo.h' )
        .and_return( 'Preprocessing partial header for a_test::Foo.h...' )

      expect(@loginator).to receive(:log).with( 'Preprocessing partial header for a_test::Foo.h...' )
      expect(@loginator).to_not receive(:log).with( anything, Verbosity::OBNOXIOUS )

      @manager.stage_preprocess_partial_headers( @state )
    end

    it "logs an OBNOXIOUS skip line for a header recalled from cache, and no NORMAL preprocessing line" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( false )
      allow(@reportinator).to receive(:generate_module_progress)
        .with( operation: 'Skipping partial header preprocessing for', module_name: 'a_test', filename: 'Foo.h' )
        .and_return( 'Skipping partial header preprocessing for a_test::Foo.h...' )

      expect(@loginator).to receive(:log).with( 'Skipping partial header preprocessing for a_test::Foo.h...', Verbosity::OBNOXIOUS )
      expect(@reportinator).to_not receive(:generate_module_progress)
        .with( operation: 'Preprocessing partial header for', module_name: anything, filename: anything )

      @manager.stage_preprocess_partial_headers( @state )
    end
  end

  context "#stage_preprocess_partial_sources" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/Foo.c' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath).and_return( 'build/preprocess/full_expansion/Foo.c' )
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return( 'build/preprocess/includes/Foo.c.yml' )
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( 'build/preprocess/raw/Foo.c' )
      allow(@preprocessinator).to receive(:preprocess_partial_source_file_preserve_macros).and_return( ['build/preprocess/raw/Foo.c', []] )
      allow(@preprocessinator).to receive(:preprocess_partial_source_expand_macros).and_return( 'build/preprocess/full_expansion/Foo.c' )
      allow(@preprocessinator).to receive(:load_includes_list).and_return( [] )

      @testable = TestInvokerTypes::Testable.new(
        :name               => 'a_test',
        :preprocess_flags   => ['-Wall'], :preprocess_defines => ['TEST'], :search_paths => ['src']
      )
      @config = Partials::ConfigFileInfo.new( filepath: 'src/Foo.c' )
      @details = TestInvokerTypes::PartialWork.new( :config => @config, :testable => @testable, :directives_only_filepath => nil )
      @state = TestInvokerTypes::PipelineState.new(
        :testables => { :a_test => @testable }, :partials_sources => [@details], :context => :test, :options => []
      )
    end

    it "registers the source's deterministic target with the source file as sole antecedent and preprocess flags/defines/search paths, preprocessing tools, and :partials config as meta" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/Foo.c',
        files: ['src/Foo.c'],
        meta:  {
          flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'],
          tools: [@tools_test_file_directives_only_preprocessor, @tools_test_bare_includes_preprocessor, @tools_test_file_full_preprocessor],
          preprocess_force_fallback: false,
          partials: @partials_config
        }
      )

      @manager.stage_preprocess_partial_sources( @state )
    end

    it "runs all three preprocessing passes and marks the target fresh once, at the end, when the dependency tracker reports it stale" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to receive(:generate_directives_only_output).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_source_file_preserve_macros).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_source_expand_macros).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/Foo.c').ordered

      @manager.stage_preprocess_partial_sources( @state )
    end

    it "skips all three preprocessing passes and reconstructs config state from the deterministic paths and cached includes list when the dependency tracker reports it unchanged" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( false )
      cached_includes = [ double("Include") ]
      allow(@preprocessinator).to receive(:load_includes_list).with( test: 'a_test', filepath: 'src/Foo.c' ).and_return( cached_includes )

      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to_not receive(:preprocess_partial_source_file_preserve_macros)
      expect(@preprocessinator).to_not receive(:preprocess_partial_source_expand_macros)
      expect(@dependinator).to_not receive(:mark_fresh)

      @manager.stage_preprocess_partial_sources( @state )

      expect( @config.directives_only_filepath ).to eq( 'build/preprocess/Foo.c' )
      expect( @config.includes ).to eq( cached_includes )
      expect( @config.full_expansion_filepath ).to eq( 'build/preprocess/full_expansion/Foo.c' )
    end

    it "does nothing for the directives-only pass when directives-only preprocessing is unavailable for this toolchain, but still runs preserve-macros and full-expansion" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to receive(:preprocess_partial_source_file_preserve_macros)
      expect(@preprocessinator).to receive(:preprocess_partial_source_expand_macros)

      @manager.stage_preprocess_partial_sources( @state )
    end

    it "logs a NORMAL progress line for a source that needs preprocessing, and no OBNOXIOUS skip line" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@reportinator).to receive(:generate_module_progress)
        .with( operation: 'Preprocessing partial source for', module_name: 'a_test', filename: 'Foo.c' )
        .and_return( 'Preprocessing partial source for a_test::Foo.c...' )

      expect(@loginator).to receive(:log).with( 'Preprocessing partial source for a_test::Foo.c...' )
      expect(@loginator).to_not receive(:log).with( anything, Verbosity::OBNOXIOUS )

      @manager.stage_preprocess_partial_sources( @state )
    end

    it "logs an OBNOXIOUS skip line for a source recalled from cache, and no NORMAL preprocessing line" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( false )
      allow(@reportinator).to receive(:generate_module_progress)
        .with( operation: 'Skipping partial source preprocessing for', module_name: 'a_test', filename: 'Foo.c' )
        .and_return( 'Skipping partial source preprocessing for a_test::Foo.c...' )

      expect(@loginator).to receive(:log).with( 'Skipping partial source preprocessing for a_test::Foo.c...', Verbosity::OBNOXIOUS )
      expect(@reportinator).to_not receive(:generate_module_progress)
        .with( operation: 'Preprocessing partial source for', module_name: anything, filename: anything )

      @manager.stage_preprocess_partial_sources( @state )
    end
  end

  context "#stage_generate_partials" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      @module_contents = double( "CModule",
        function_definitions:    [],
        function_declarations:   [],
        type_definitions:        [],
        aggregate_definitions:   []
      )
      allow(@partializer).to receive(:extract_module_contents).and_return( @module_contents )
      allow(@partializer).to receive(:validate_config)
      allow(@partializer).to receive(:sanitize)
      allow(@partializer).to receive(:validate_extracted_functions)
      allow(@partializer).to receive(:remap_implementation_header_includes).and_return( [] )
      allow(@partializer).to receive(:remap_implementation_source_includes).and_return( [] )
      allow(@partializer).to receive(:remap_interface_header_includes).and_return( [] )
      allow(@partializer).to receive(:remap_types_header_includes).and_return( [] )
      allow(@partializer).to receive(:extract_module_include_guard).and_return( 'FOO_H' )
      allow(@generator).to receive(:generate_partial_types)
      allow(@generator).to receive(:generate_partial_implementation)
      allow(@generator).to receive(:generate_partial_interface)

      allow(@file_path_utils).to receive(:form_partial_types_header_filename).and_return( 'ceedling_partial_Foo_types.h' )
      allow(@file_path_utils).to receive(:form_partial_implementation_source_filename).and_return( 'ceedling_partial_Foo_impl.c' )
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename).and_return( 'ceedling_partial_Foo_impl.h' )
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename).and_return( 'ceedling_partial_Foo_interface.h' )

      allow(@dependinator).to receive(:register)
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@dependinator).to receive(:mark_fresh)

      @config = Partials::Config.new(
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
        .and_return( [UserInclude.new('foundation.h')] )

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, meta: {}, **|
        expect( meta[:include_guard] ).to eq( 'FOO_H' )
        expect( meta[:types_includes] ).to eq( ['#include "foundation.h"'] )
      end

      @manager.stage_generate_partials( @state )
    end

    it "hands the guard and the carried include list to types generation" do
      allow(@module_contents).to receive(:type_definitions).and_return( [double("TypeDef")] )
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      carried = [UserInclude.new('foundation.h')]
      allow(@partializer).to receive(:remap_types_header_includes).and_return( carried )

      expect(@generator).to receive(:generate_partial_types).with(
        hash_including( includes: carried, include_guard: 'FOO_H' )
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

    it "reads the guard from the module's own header" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      expect(@partializer).to receive(:extract_module_include_guard).with( 'src/Foo.h' )

      @manager.stage_generate_partials( @state )
    end

    # Fallback resolves strictly less than the accurate pass, and validate_config refuses the
    # shapes it cannot handle. The stage has to tell it which path ran.
    it "tells config validation whether preprocessing fell back" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [] )

      expect(@partializer).to receive(:validate_config).with( hash_including( fallback: true ) )

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

    it "logs summary lines stating how many of each Partial artifact were recalled from cache" do
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
