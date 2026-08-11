# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filename_extension'
require 'rake'
require 'ceedling/test_invoker/test_build_executor'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/partials/partials'
require 'ceedling/test_context_extractor'

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
    @tools_test_linker    = { name: 'fake linker' }
    @tools_test_fixture   = { name: 'fake fixture' }

    allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.asm') )
    allow(@configurator).to receive(:tools_test_compiler).and_return( @tools_test_compiler )
    allow(@configurator).to receive(:tools_test_assembler).and_return( @tools_test_assembler )
    allow(@configurator).to receive(:tools_test_linker).and_return( @tools_test_linker )
    allow(@configurator).to receive(:tools_test_fixture).and_return( @tools_test_fixture )
    allow(@configurator).to receive(:project_use_mocks).and_return( false )
    allow(@configurator).to receive(:project_use_exceptions).and_return( false )
    allow(@configurator).to receive(:collection_all_support).and_return( [] )

    allow(@file_path_utils).to receive(:form_test_build_list_filepath).and_return( 'build/list' )
    allow(@file_path_utils).to receive(:form_test_dependencies_filepath).and_return( 'build/deps' )
    allow(@file_path_utils).to receive(:form_preprocessed_source_files_cache_filepath).and_return( 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml' )

    allow(@file_wrapper).to receive(:mkdir)

    allow(@reportinator).to receive(:generate_module_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_progress).and_return( '' )
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:log_list)
    allow(@test_context_extractor).to receive(:store_build_directives_cache)
    allow(@test_context_extractor).to receive(:load_build_directives_cache)

    # Default: no prior `.d` file on disk, and the tracker reports every target
    # stale -- i.e. every real build in this spec proceeds as an unconditional
    # fresh compile unless a test overrides `stale?` to exercise the skip path.
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

  context "#stage_build_objects" do
    before(:each) do
      stub_batchinator_exec()

      allow(@file_finder).to receive(:find_build_input_file).and_return( 'src/foo.c' )
      allow(@file_wrapper).to receive(:extname).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )

      @testable = TestInvokerTypes::Testable.new(
        :name              => 'a_test',
        :compile_defines   => [], :search_paths => [], :compile_flags => []
      )
      @state = TestInvokerTypes::PipelineState.new(
        :testables   => { :a_test => @testable },
        :objects_list => [ { test: :a_test, obj: 'build/foo.o' } ],
        :lock => Mutex.new, :context => :test, :options => []
      )
    end

    it "logs a summary line stating how many objects were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping compilation for 1 object (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping compilation for 1 object (nothing changed)..." )
      @executor.stage_build_objects( @state )
    end

    it "logs no summary line when every object needed compiling" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@generator).to receive(:generate_object_file_c)

      expect(@loginator).to_not receive(:log).with( /Skipping compilation/ )

      @executor.stage_build_objects( @state )
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
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
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

    it "logs a summary line stating how many executables were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping linking for 1 executable (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping linking for 1 executable (nothing changed)..." )
      @executor.stage_build_executables( @state )
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
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "runs the test fixture when stage 16 rebuilt the executable, first clearing any stale prior result" do
      @testable.executable_rebuilt = true
      allow(@file_wrapper).to receive(:rm_f)
      expect(@file_wrapper).to receive(:rm_f).with( Dir.glob( File.join( 'build/test/results', 'a_test.*' ) ) )
      expect(@generator).to receive(:generate_test_results).with( hash_including( skipped: false ) )

      @executor.stage_execute( @state )
    end

    it "reports the cached result instead of running the test fixture when stage 16 found the executable unchanged, and does not touch the cached result file" do
      @testable.executable_rebuilt = false
      expect(@generator).to receive(:generate_test_results).with( hash_including( skipped: true ) )
      expect(@file_wrapper).to_not receive(:rm_f)

      @executor.stage_execute( @state )
    end

    it "always fires the post_test plugin hook, rebuilt or not" do
      @testable.executable_rebuilt = false
      allow(@generator).to receive(:generate_test_results)
      expect(@plugin_manager).to receive(:post_test).with('test/TestFoo.c')

      @executor.stage_execute( @state )
    end

    it "logs a summary line stating how many tests reused a cached result" do
      @testable.executable_rebuilt = false
      allow(@generator).to receive(:generate_test_results)

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test execution for 1 test (reusing cached results)..." )

      expect(@loginator).to receive(:log).with( "Skipping test execution for 1 test (reusing cached results)..." )
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
      mock = TestInvokerTypes::MockWork.new(
        :details  => TestInvokerTypes::MockDetails.new( :source => 'src/Foo.h', :path => 'sub' ),
        :testable => @testable,
        :name     => :MockFoo,
        :directives_only_filepath => nil
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :mocks_list => [mock], :context => :test, :options => [] )
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

    it "logs a summary line stating how many mocks' preprocessing was recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping mock preprocessing for 1 mock (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping mock preprocessing for 1 mock (nothing changed)..." )
      @executor.stage_preprocess_mocks( @state )
    end
  end

  context "#stage_generate_mocks" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@configurator).to receive(:get_cmock_config).and_return( { mock_prefix: 'Mock' } )
      allow(@file_wrapper).to receive(:mkdir)

      @testable = TestInvokerTypes::Testable.new(
        :name  => 'a_test',
        :paths => { :mocks => 'build/test/mocks' }
      )
      mock = TestInvokerTypes::MockWork.new(
        :details  => TestInvokerTypes::MockDetails.new(
          :source => 'src/Foo.h', :path => 'sub', :input => 'build/preprocess/MockFoo.h', :name => 'MockFoo'
        ),
        :testable => @testable,
        :name     => :MockFoo
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :mocks_list => [mock], :lock => Mutex.new, :context => :test, :options => [] )
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

    it "logs a summary line stating how many mocks were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping mock generation for 1 mock (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping mock generation for 1 mock (nothing changed)..." )
      @executor.stage_generate_mocks( @state )
    end

    it "tracks the mock's own generated header, not just its source input, as a dependency" do
      # stage_collect_preprocessor_context's includes stand-in generation
      # (test_build_setup.rb) can overwrite a mock's generated header with a
      # blank placeholder on a run where only the *test* file's own
      # bare-includes cache misses -- unrelated to whether this mock's own
      # antecedents changed. Tracking the header file itself, not just the
      # source input, is what lets that overwrite be detected and the mock
      # regenerated on the next run.
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

    it "registers CMock's actual configuration as meta, not project_config_hash's flattened (and therefore always-empty) :cmock entry" do
      # project_config_hash is flattened -- CMock's settings live there as individual
      # top-level keys like :cmock_mock_prefix, never as a :cmock section -- so a
      # config change (e.g. :cmock ↳ :mock_prefix) can only be detected here via
      # get_cmock_config, the one place CMock's configuration still exists as a
      # single value.
      allow(@configurator).to receive(:get_cmock_config).and_return( { mock_prefix: 'Custom' } )
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@generator).to receive(:generate_mock)
      allow(@dependinator).to receive(:mark_fresh)

      expect(@dependinator).to receive(:register).with(
        'build/test/mocks/sub/MockFoo.c',
        files: anything,
        meta:  { cmock: { mock_prefix: 'Custom' } }
      )

      @executor.stage_generate_mocks( @state )
    end
  end

  context "#stage_collect_runner_details" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@configurator).to receive(:get_runner_config).and_return( {} )
      allow(@configurator).to receive(:get_unity_config).and_return( {} )
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@test_context_extractor).to receive(:collect_test_runner_details)

      @testable = TestInvokerTypes::Testable.new(
        :name     => 'a_test',
        :filepath => 'test/TestFoo.c',
        :runner   => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => 'build/preprocess/files/TestFoo.c' )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "parses test case names when the runner target the dependency tracker reports is stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@test_context_extractor).to receive(:collect_test_runner_details).with( 'test/TestFoo.c', 'build/preprocess/files/TestFoo.c' )

      @executor.stage_collect_runner_details( @state )
    end

    it "does nothing when the runner target the dependency tracker reports is unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_context_extractor).to_not receive(:collect_test_runner_details)

      @executor.stage_collect_runner_details( @state )
    end

    it "registers the real test runner and Unity configuration as meta, not project_config_hash's flattened (and therefore always-empty) :test_runner/:unity entries" do
      # project_config_hash is flattened -- these sections live there as individual
      # top-level keys like :unity_use_param_tests, never as :test_runner/:unity
      # sections -- so a config change in either can only be detected here via
      # get_runner_config/get_unity_config.
      allow(@configurator).to receive(:get_runner_config).and_return( { mock_prefix: 'Custom' } )
      allow(@configurator).to receive(:get_unity_config).and_return( { use_param_tests: true } )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: anything,
        meta:  { test_runner: { mock_prefix: 'Custom' }, unity: { use_param_tests: true }, test_preprocessor_tests: true }
      )

      @executor.stage_collect_runner_details( @state )
    end

    it "registers the same target and meta stage 13 uses for the runner itself" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: ['test/TestFoo.c'],
        meta:  { test_runner: {}, unity: {}, test_preprocessor_tests: true }
      )

      @executor.stage_collect_runner_details( @state )
    end

    it "logs a summary line stating how many test files' test case name parsing was recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test case name parsing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test case name parsing for 1 test file (nothing changed)..." )
      @executor.stage_collect_runner_details( @state )
    end
  end

  context "#stage_generate_runners" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:project_config_hash).and_return( {} )
      allow(@configurator).to receive(:get_runner_config).and_return( {} )
      allow(@configurator).to receive(:get_unity_config).and_return( {} )
      allow(@configurator).to receive(:project_use_test_preprocessor_tests).and_return( true )
      allow(@test_context_extractor).to receive(:lookup_mock_header_includes_list).and_return( [] )
      allow(@test_context_extractor).to receive(:lookup_nonmock_header_includes_list).and_return( [] )

      @testable = TestInvokerTypes::Testable.new(
        :name     => 'a_test',
        :filepath => 'test/TestFoo.c',
        :runner   => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => 'test/TestFoo.c' )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
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

    it "logs a summary line stating how many test runners were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test runner generation for 1 test runner (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test runner generation for 1 test runner (nothing changed)..." )
      @executor.stage_generate_runners( @state )
    end

    it "includes whether test files are preprocessed in the registered meta, so toggling it invalidates the runner" do
      allow(@generator).to receive(:generate_test_runner)

      expect(@dependinator).to receive(:register).with(
        'build/test/runners/TestFoo_runner.c',
        files: ['test/TestFoo.c'],
        meta:  hash_including( test_preprocessor_tests: true )
      )

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
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
      allow(@test_context_extractor).to receive(:collect_simple_context_from_file)
      allow(@reportinator).to receive(:generate_progress).and_return( '' )
      allow(@loginator).to receive(:log)

      @testable = TestInvokerTypes::Testable.new(
        :name               => 'a_test',
        :filepath           => 'test/TestFoo.c',
        :preprocess         => { :directives_only => { :filepath => nil } },
        :preprocess_flags   => [], :preprocess_defines => [], :search_paths => [],
        :runner             => TestInvokerTypes::RunnerInfo.new( :output_filepath => 'build/test/runners/TestFoo_runner.c', :input_filepath => nil )
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
    end

    it "preprocesses and marks fresh the test file, storing its output as the runner input, when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      expect(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/files/TestFoo.c')

      @executor.stage_preprocess_test_files( @state )

      expect( @testable.runner.input_filepath ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "skips preprocessing and reuses the deterministic path as the runner input when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )
      expect(@preprocessinator).to_not receive(:preprocess_test_file)
      expect(@dependinator).to_not receive(:mark_fresh)

      @executor.stage_preprocess_test_files( @state )

      expect( @testable.runner.input_filepath ).to eq('build/preprocess/files/TestFoo.c')
    end

    it "scans and caches source directive macros when the dependency tracker reports it stale" do
      allow(@dependinator).to receive(:stale?).and_return( true )
      allow(@preprocessinator).to receive(:preprocess_test_file).and_return( 'build/preprocess/files/TestFoo.c' )

      expect(@test_context_extractor).to receive(:collect_simple_context_from_file)
      expect(@test_context_extractor).to receive(:store_build_directives_cache).with(
        filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml'
      )
      expect(@test_context_extractor).to_not receive(:load_build_directives_cache)

      @executor.stage_preprocess_test_files( @state )
    end

    it "recalls cached source directive macros instead of scanning when the dependency tracker reports it unchanged" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_context_extractor).to_not receive(:collect_simple_context_from_file)
      expect(@test_context_extractor).to receive(:load_build_directives_cache).with(
        filepath: 'test/TestFoo.c', cache_filepath: 'build/preprocess/build_directives/a_test/TestFoo.c_source_files.yml'
      )

      @executor.stage_preprocess_test_files( @state )
    end

    it "logs a summary line stating how many test files' preprocessing (and source directive macros) were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping test file preprocessing for 1 test file (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping test file preprocessing for 1 test file (nothing changed)..." )
      @executor.stage_preprocess_test_files( @state )
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

      @executor.stage_preprocess_partial_headers( @state )
    end

    it "runs all three preprocessing passes and marks the target fresh once, at the end, when the dependency tracker reports it stale" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to receive(:generate_directives_only_output).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_header_file_preserve_macros).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_header_expand_macros).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/Foo.h').ordered

      @executor.stage_preprocess_partial_headers( @state )
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

      @executor.stage_preprocess_partial_headers( @state )

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

      @executor.stage_preprocess_partial_headers( @state )
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

      @executor.stage_preprocess_partial_sources( @state )
    end

    it "runs all three preprocessing passes and marks the target fresh once, at the end, when the dependency tracker reports it stale" do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )
      allow(@dependinator).to receive(:stale?).and_return( true )

      expect(@preprocessinator).to receive(:generate_directives_only_output).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_source_file_preserve_macros).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_source_expand_macros).ordered
      expect(@dependinator).to receive(:mark_fresh).with('build/preprocess/Foo.c').ordered

      @executor.stage_preprocess_partial_sources( @state )
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

      @executor.stage_preprocess_partial_sources( @state )

      expect( @config.directives_only_filepath ).to eq( 'build/preprocess/Foo.c' )
      expect( @config.includes ).to eq( cached_includes )
      expect( @config.full_expansion_filepath ).to eq( 'build/preprocess/full_expansion/Foo.c' )
    end
  end

  context "#stage_generate_partials" do
    before(:each) do
      stub_batchinator_exec()

      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      module_contents = double( "CModule", function_definitions: [], function_declarations: [] )
      allow(@partializer).to receive(:extract_module_contents).and_return( module_contents )
      allow(@partializer).to receive(:validate_config)
      allow(@partializer).to receive(:sanitize)
      allow(@partializer).to receive(:validate_extracted_functions)
      allow(@partializer).to receive(:remap_implementation_header_includes).and_return( [] )
      allow(@partializer).to receive(:remap_implementation_source_includes).and_return( [] )
      allow(@partializer).to receive(:remap_interface_header_includes).and_return( [] )
      allow(@generator).to receive(:generate_partial_types)
      allow(@generator).to receive(:generate_partial_implementation)
      allow(@generator).to receive(:generate_partial_interface)

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

      @executor.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( ['Foo'] )
      expect( @testable.partials.mocks ).to eq( ['Foo'] )
    end

    it "does not add to tests when no implementation is extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( nil )
      allow(@partializer).to receive(:extract_interface_functions).and_return( [double("FunctionDeclaration")] )

      @executor.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( [] )
      expect( @testable.partials.mocks ).to eq( ['Foo'] )
    end

    it "does not add to mocks when no interface is extracted" do
      allow(@partializer).to receive(:extract_implementation_functions).and_return( [double("FunctionDefinition")] )
      allow(@partializer).to receive(:extract_interface_functions).and_return( nil )

      @executor.stage_generate_partials( @state )

      expect( @testable.partials.tests ).to eq( ['Foo'] )
      expect( @testable.partials.mocks ).to eq( [] )
    end
  end
end
