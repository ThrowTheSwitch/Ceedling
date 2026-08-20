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

    it "registers the header's deterministic target with the header file as sole antecedent and preprocess flags/defines/search paths as meta" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/Foo.h',
        files: ['src/Foo.h'],
        meta:  { flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'] }
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

    it "registers the source's deterministic target with the source file as sole antecedent and preprocess flags/defines/search paths as meta" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/Foo.c',
        files: ['src/Foo.c'],
        meta:  { flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'] }
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
      allow(@configurator).to receive(:partials_max_extraction_length).and_return( 5 )

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

      expect(@dependinator).to receive(:register).at_least(:once) do |_target, files:, meta:|
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
