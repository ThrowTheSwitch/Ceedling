# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake'
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
    @dependinator                                          = double( "Dependinator" )

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

    # Default: no prior `.d` file on disk, and the tracker reports every target
    # stale -- i.e. every real build in this spec proceeds as if it were a
    # fresh compile, matching these tests' original (pre-staleness) behavior.
    allow(@file_wrapper).to receive(:exist?).and_return( false )
    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:register_gcc_deps_file)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)

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
        :file_wrapper            => @file_wrapper,
        :dependinator            => @dependinator
      }
    )

    testable = TestInvokerTypes::Testable.new(
      :compile_defines  => [],
      :search_paths     => [],
      :compile_flags    => [],
      :assembler_flags  => []
    )

    @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => testable }, :lock => Mutex.new )
  end

  # `@batchinator.exec` is a real collaborator only in production; here it's
  # stubbed to synchronously yield every `things` entry to the given block,
  # matching its real per-item iteration contract without pulling in Parallel.
  def stub_batchinator_exec
    allow(@batchinator).to receive(:exec) do |workload:, things:, &block|
      things.each { |k, v| block.call(k, v) }
    end
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

    it "skips compiling and does not mark the object fresh when the dependency tracker reports it unchanged" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@generator).to_not receive(:generate_object_file_c)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.c', :object => 'build/foo.o', :state => @state
      )
    end

    it "registers the object's source before checking staleness, and its freshly-written gcc deps file after a real compile" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
      allow(@file_wrapper).to receive(:exist?).with('build/deps').and_return( true )

      expect(@dependinator).to receive(:register).with( 'build/foo.o', files: ['src/foo.c'], meta: anything ).ordered
      expect(@dependinator).to receive(:register_gcc_deps_file).with('build/deps').ordered # pre-compile: prior .d file, if any
      expect(@dependinator).to receive(:stale?).with('build/foo.o').and_return(true).ordered
      expect(@generator).to receive(:generate_object_file_c).ordered
      expect(@dependinator).to receive(:register_gcc_deps_file).with('build/deps').ordered # post-compile: freshly-written .d file
      expect(@dependinator).to receive(:mark_fresh).with('build/foo.o').ordered

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.c', :object => 'build/foo.o', :state => @state
      )
    end
  end

  context "#stage_build_executables" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@file_path_utils).to receive(:form_test_build_map_filepath).and_return( 'build/map' )

      @testable = TestInvokerTypes::Testable.new(
        :name       => 'a_test',
        :objects    => ['build/foo.o'],
        :executable => 'build/a_test.out',
        :link_flags => [],
        :paths      => { :build => 'build/test' }
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => {} )
    end

    it "links and marks the executable fresh, and records that it was rebuilt, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@generator).to receive(:generate_executable_file)
      expect(@dependinator).to receive(:mark_fresh).with('build/a_test.out')

      @executor.stage_build_executables( @state )

      expect( @testable.executable_rebuilt ).to be(true)
    end

    it "skips linking and records that it was not rebuilt when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@generator).to_not receive(:generate_executable_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_build_executables( @state )

      expect( @testable.executable_rebuilt ).to be(false)
    end
  end

  context "#stage_execute" do
    before(:each) do
      stub_batchinator_exec()
      allow(@plugin_manager).to receive(:post_test)

      @testable = TestInvokerTypes::Testable.new(
        :name         => 'a_test',
        :filepath     => 'test/TestFoo.c',
        :executable   => 'build/a_test.out',
        :results_pass => 'build/a_test.pass',
        :paths        => { :results => 'build/test/results' }
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :context => :test, :options => {} )
    end

    it "runs the test fixture when stage 16 rebuilt the executable, first clearing any stale prior result" do
      @testable.executable_rebuilt = true
      allow(@file_wrapper).to receive(:rm_f)
      expect(@file_wrapper).to receive(:rm_f).with( Dir.glob( File.join( 'build/test/results', 'a_test.*' ) ) )
      expect(@generator).to receive(:generate_test_results)

      @executor.stage_execute( @state )
    end

    it "does not run the test fixture or touch its cached result file when stage 16 found the executable unchanged" do
      @testable.executable_rebuilt = false
      expect(@generator).to_not receive(:generate_test_results)
      expect(@file_wrapper).to_not receive(:rm_f)

      @executor.stage_execute( @state )
    end

    it "always fires the post_test plugin hook, rebuilt or not" do
      @testable.executable_rebuilt = false
      expect(@plugin_manager).to receive(:post_test).with('test/TestFoo.c')

      @executor.stage_execute( @state )
    end
  end

  context "#stage_preprocess_mocks" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@configurator).to receive(:cmock_treat_inlines).and_return( :exclude )
      allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/MockFoo.h' )

      @testable = TestInvokerTypes::Testable.new(
        :name             => 'a_test',
        :preprocess_flags => [], :preprocess_defines => [], :search_paths => []
      )
      mock = {
        :details  => { :source => 'src/Foo.h', :path => 'sub' },
        :testable => @testable,
        :name     => :MockFoo,
        :directives_only_filepath => nil
      }
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :mocks_list => [mock], :context => :test, :options => {} )
    end

    it "preprocesses and marks fresh the mockable header when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:preprocess_mockable_header_file)
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/MockFoo.h')

      @executor.stage_preprocess_mocks( @state )
    end

    it "skips preprocessing the mockable header when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:preprocess_mockable_header_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_preprocess_mocks( @state )
    end
  end

  context "#stage_generate_mocks" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@file_wrapper).to receive(:mkdir)

      @testable = TestInvokerTypes::Testable.new(
        :name  => 'a_test',
        :paths => { :mocks => 'build/test/mocks' }
      )
      mock = {
        :details  => { :source => 'src/Foo.h', :path => 'sub', :input => 'build/preprocess/MockFoo.h', :name => 'MockFoo' },
        :testable => @testable,
        :name     => :MockFoo
      }
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :mocks_list => [mock], :context => :test, :options => {} )
    end

    it "generates and marks fresh the mock when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@generator).to receive(:generate_mock)
      expect(@dependinator).to receive(:mark_fresh).with('build/test/mocks/sub/MockFoo.c')

      @executor.stage_generate_mocks( @state )
    end

    it "skips generating the mock when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@generator).to_not receive(:generate_mock)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_generate_mocks( @state )
    end

    it "tracks the mock's own generated header, not just its source input, as a dependency" do
      # Regression coverage: stage_collect_preprocessor_context's includes
      # stand-in generation (test_build_setup.rb) can overwrite a mock's
      # generated header with a blank placeholder on a run where only the
      # *test* file's own bare-includes cache misses -- unrelated to whether
      # this mock's own antecedents changed. Without tracking the header file
      # itself, that overwrite goes completely undetected and a stale/blank
      # mock header silently ships to the compiler on a run that skips
      # regenerating this mock.
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@generator).to receive(:generate_mock)
      allow(@dependinator).to receive(:mark_fresh)

      expect(@dependinator).to receive(:register).with(
        'build/test/mocks/sub/MockFoo.c',
        files: ['build/preprocess/MockFoo.h', 'build/test/mocks/sub/MockFoo.h'],
        meta:  anything
      )

      @executor.stage_generate_mocks( @state )
    end
  end

  context "#stage_generate_runners" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list).and_return( [] )

      @testable = TestInvokerTypes::Testable.new(
        :name     => 'a_test',
        :filepath => 'test/TestFoo.c',
        :runner   => { :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => 'test/TestFoo.c' }
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :context => :test, :options => {} )
    end

    it "generates and marks fresh the runner when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@generator).to receive(:generate_test_runner)
      expect(@dependinator).to receive(:mark_fresh).with('build/test/runners/TestFoo_runner.c')

      @executor.stage_generate_runners( @state )
    end

    it "skips generating the runner when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@generator).to_not receive(:generate_test_runner)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_generate_runners( @state )
    end
  end

  context "#stage_preprocess_test_files" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )
      allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( 'build/preprocess/files/TestFoo.c' )
      allow(@test_context_extractor).to receive(:lookup_all_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list).and_return( [] )
      allow(@configurator).to receive(:extension_source).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file)
      allow(@reportinator).to receive(:generate_progress).and_return( '' )
      allow(@loginator).to receive(:log)

      @testable = TestInvokerTypes::Testable.new(
        :name               => 'a_test',
        :filepath           => 'test/TestFoo.c',
        :preprocess         => { :directives_only => { :filepath => nil } },
        :preprocess_flags   => [], :preprocess_defines => [], :search_paths => [],
        :runner             => { :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => nil }
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => {} )
    end

    it "preprocesses and marks fresh the test file, storing its output as the runner input, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/files/TestFoo.c')

      @executor.stage_preprocess_test_files( @state )

      expect( @testable.runner[:input_filepath] ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "skips preprocessing and reuses the deterministic path as the runner input when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:preprocess_test_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_preprocess_test_files( @state )

      expect( @testable.runner[:input_filepath] ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "still collects build-directive context every run, regardless of staleness" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@test_context_extractor).to receive(:collect_simple_context_from_file)

      @executor.stage_preprocess_test_files( @state )
    end
  end
end
