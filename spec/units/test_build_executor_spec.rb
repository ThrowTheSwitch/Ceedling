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
    @generator                           = double( "Generator" )
    @test_context_extractor                 = double( "TestContextExtractor" )
    @plugin_manager                            = double( "PluginManager" )
    @file_path_utils                              = double( "FilePathUtils" )
    @file_finder                                     = double( "FileFinder" )
    @file_wrapper                                       = double( "FileWrapper" )
    @dependinator                                          = double( "Dependinator" )
    @test_source_file_directive_resolver                      = double( "TestSourceFileDirectiveResolver" )

    @tools_test_compiler                     = { name: 'fake compiler' }
    @tools_test_assembler                    = { name: 'fake assembler' }
    @tools_test_linker                       = { name: 'fake linker' }
    @tools_test_fixture                      = { name: 'fake fixture' }
    @tools_test_bare_includes_preprocessor   = { name: 'fake bare includes preprocessor' }
    @tools_test_file_directives_only_preprocessor = { name: 'fake directives-only preprocessor' }

    allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.asm') )
    allow(@configurator).to receive(:tools_test_compiler).and_return( @tools_test_compiler )
    allow(@configurator).to receive(:tools_test_assembler).and_return( @tools_test_assembler )
    allow(@configurator).to receive(:tools_test_linker).and_return( @tools_test_linker )
    allow(@configurator).to receive(:tools_test_fixture).and_return( @tools_test_fixture )
    allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return( @tools_test_bare_includes_preprocessor )
    allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return( @tools_test_file_directives_only_preprocessor )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@configurator).to receive(:project_use_mocks).and_return( false )
    allow(@configurator).to receive(:project_use_exceptions).and_return( false )
    allow(@configurator).to receive(:collection_all_support).and_return( [] )
    allow(@configurator).to receive(:force_test_rerun).and_return( false )
    allow(@configurator).to receive(:unity_shuffle_tests).and_return( false )

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
    # Default: no plugin implements the new pre-*-register hooks -- each is a
    # no-op that leaves the arg_hash it's handed untouched.
    allow(@plugin_manager).to receive(:pre_test_compile_register)
    allow(@plugin_manager).to receive(:pre_test_link_register)
    allow(@plugin_manager).to receive(:pre_test_fixture_register)

    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:register_gcc_deps_file)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)
    allow(@test_source_file_directive_resolver).to receive(:validate!)

    @executor = described_class.new(
      {
        :configurator            => @configurator,
        :loginator               => @loginator,
        :reportinator            => @reportinator,
        :batchinator             => @batchinator,
        :preprocessinator        => @preprocessinator,
        :generator               => @generator,
        :test_context_extractor  => @test_context_extractor,
        :plugin_manager          => @plugin_manager,
        :file_path_utils         => @file_path_utils,
        :file_finder             => @file_finder,
        :file_wrapper            => @file_wrapper,
        :dependinator            => @dependinator,
        :test_source_file_directive_resolver => @test_source_file_directive_resolver
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

    it "resolves the compile tool/flags/defines through pre_test_compile_register before registering staleness meta, and uses the resolved values for the real compile" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )

      swapped_tool = { name: 'fake gcov compiler' }
      allow(@plugin_manager).to receive(:pre_test_compile_register) do |arg_hash|
        arg_hash[:tool]    = swapped_tool
        arg_hash[:flags]   += ['-fcondition-coverage']
        arg_hash[:defines] += ['CODE_COVERAGE']
      end

      expect(@dependinator).to receive(:register).with(
        'build/foo.o',
        files: ['src/foo.c'],
        meta:  hash_including(
          tools:   [swapped_tool],
          flags:   array_including('-fcondition-coverage'),
          defines: array_including('CODE_COVERAGE')
        )
      )
      expect(@generator).to receive(:generate_object_file_c) do |**args|
        expect( args[:tool] ).to eq( swapped_tool )
        expect( args[:flags] ).to include('-fcondition-coverage')
        expect( args[:defines] ).to include('CODE_COVERAGE')
      end

      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.c', :object => 'build/foo.o', :state => @state
      )
    end

    it "registers the configured compiler tool as meta for a C source, and the configured assembler tool for an assembly source" do
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.c' ).and_return( '.c' )
      allow(@file_wrapper).to receive(:extname).with( 'src/foo.asm' ).and_return( '.asm' )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( true )
      allow(@generator).to receive(:generate_object_file_c)
      allow(@generator).to receive(:generate_object_file_asm)

      expect(@dependinator).to receive(:register).with( 'build/foo.o', files: ['src/foo.c'], meta: hash_including( tools: [@tools_test_compiler] ) )
      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.c', :object => 'build/foo.o', :state => @state
      )

      expect(@dependinator).to receive(:register).with( 'build/foo.o', files: ['src/foo.asm'], meta: hash_including( tools: [@tools_test_assembler] ) )
      @executor.send(
        :compile_test_component,
        :context => :test, :test => :a_test, :source => 'src/foo.asm', :object => 'build/foo.o', :state => @state
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
        :objects_list => [ TestInvokerTypes::ObjectWork.new( test: :a_test, obj: 'build/foo.o' ) ],
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

    it "resolves the link tool/flags through pre_test_link_register before registering staleness meta, and uses the resolved values for the real link" do
      allow(@dependinator).to receive(:stale?).and_return( true )

      swapped_tool = { name: 'fake bullseye linker' }
      allow(@plugin_manager).to receive(:pre_test_link_register) do |arg_hash|
        arg_hash[:tool] = swapped_tool
      end

      expect(@dependinator).to receive(:register).with(
        'build/a_test.out',
        files: ['build/foo.o'],
        meta:  hash_including( tools: [swapped_tool] )
      )
      expect(@generator).to receive(:generate_executable_file) do |tool, *_rest|
        expect( tool ).to eq( swapped_tool )
      end

      @executor.stage_build_executables( @state )
    end

    it "registers the configured test linker tool as meta, alongside link flags and library arguments" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@dependinator).to receive(:register).with(
        'build/a_test.out',
        files: ['build/foo.o'],
        meta:  { flags: [], lib_args: [], lib_paths: [], tools: [@tools_test_linker] }
      )

      @executor.stage_build_executables( @state )
    end

    it "logs a summary line stating how many executables were recalled from cache" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      allow(@reportinator).to receive(:generate_skip_summary).and_return( "Skipping linking for 1 executable (nothing changed)..." )

      expect(@loginator).to receive(:log).with( "Skipping linking for 1 executable (nothing changed)..." )
      @executor.stage_build_executables( @state )
    end
  end

  context "#generate_executable" do
    before(:each) do
      allow(@file_path_utils).to receive(:form_test_build_map_filepath).and_return( 'build/map' )
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
    end

    def build_args
      {
        context:    :test,
        build_path: 'build/test',
        executable: 'build/a_test.out',
        objects:    ['build/foo.o'],
        flags:      [],
        lib_args:   [],
        lib_paths:  [],
        tool:       { name: 'fake linker' }
      }
    end

    it "re-raises a ShellException from the linker" do
      ex = ShellException.new( shell_result: { output: 'some unrelated linker failure' }, name: 'linker' )
      allow(@generator).to receive(:generate_executable_file).and_raise( ex )
      allow(@loginator).to receive(:log)

      expect {
        @executor.generate_executable( **build_args )
      }.to raise_error( ShellException )
    end

    it "logs missing-symbols guidance when the shell output mentions a symbol, before re-raising" do
      ex = ShellException.new( shell_result: { output: 'undefined reference to symbol foo' }, name: 'linker' )
      allow(@generator).to receive(:generate_executable_file).and_raise( ex )

      expect(@loginator).to receive(:log).with(
        a_string_matching(/missing symbols/i),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      expect {
        @executor.generate_executable( **build_args )
      }.to raise_error( ShellException )
    end

    it "does not log guidance when the shell output does not mention a symbol" do
      ex = ShellException.new( shell_result: { output: 'some unrelated linker failure' }, name: 'linker' )
      allow(@generator).to receive(:generate_executable_file).and_raise( ex )

      expect(@loginator).to_not receive(:log)

      expect {
        @executor.generate_executable( **build_args )
      }.to raise_error( ShellException )
    end

    it "includes mock-specific guidance only when the project uses mocks" do
      ex = ShellException.new( shell_result: { output: 'missing symbol foo' }, name: 'linker' )
      allow(@generator).to receive(:generate_executable_file).and_raise( ex )
      allow(@configurator).to receive(:project_use_mocks).and_return( true )

      expect(@loginator).to receive(:log).with(
        a_string_matching(/needed mocks/i),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      expect {
        @executor.generate_executable( **build_args )
      }.to raise_error( ShellException )
    end

    it "does not raise when the linker succeeds" do
      allow(@generator).to receive(:generate_executable_file)

      expect { @executor.generate_executable( **build_args ) }.to_not raise_error
    end
  end

  context "#stage_execute" do
    before(:each) do
      stub_batchinator_exec()
      allow(@plugin_manager).to receive(:post_test)

      # This context's own tests are about executable_rebuilt/force_rerun/shuffle
      # deciding whether a fixture reruns, so the fixture-target's own staleness
      # (the tool-config trigger) defaults to fresh here -- see the dedicated
      # "tool configuration changed" examples below for that case on its own.
      allow(@dependinator).to receive(:stale?).and_return( false )
      allow(@file_wrapper).to receive(:touch)

      @testable = TestInvokerTypes::Testable.new(
        :name         => 'a_test',
        :filepath     => 'test/TestFoo.c',
        :executable   => 'build/a_test.out',
        :results_pass => 'build/a_test.pass',
        :paths        => { :results => 'build/test/results' }
      )
      @state = TestInvokerTypes::PipelineState.new( :testables => { :a_test => @testable }, :lock => Mutex.new, :context => :test, :options => [] )
      @fixture_target = 'build/test/results/a_test.fixture_run'
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

    it "runs the test fixture and clears any stale prior result when :force_test_rerun is enabled, even though the executable is unchanged" do
      @testable.executable_rebuilt = false
      allow(@configurator).to receive(:force_test_rerun).and_return( true )
      allow(@file_wrapper).to receive(:rm_f)
      expect(@file_wrapper).to receive(:rm_f).with( Dir.glob( File.join( 'build/test/results', 'a_test.*' ) ) )
      expect(@generator).to receive(:generate_test_results).with( hash_including( skipped: false ) )

      @executor.stage_execute( @state )
    end

    it "runs the test fixture and clears any stale prior result when :unity ↳ :shuffle_tests is enabled, even though the executable is unchanged" do
      @testable.executable_rebuilt = false
      allow(@configurator).to receive(:unity_shuffle_tests).and_return( true )
      allow(@file_wrapper).to receive(:rm_f)
      expect(@file_wrapper).to receive(:rm_f).with( Dir.glob( File.join( 'build/test/results', 'a_test.*' ) ) )
      expect(@generator).to receive(:generate_test_results).with( hash_including( skipped: false ) )

      @executor.stage_execute( @state )
    end

    it "logs a NOTICE that shuffling is overriding a delta-build skip when :unity ↳ :shuffle_tests is enabled and the executable is unchanged" do
      @testable.executable_rebuilt = false
      allow(@configurator).to receive(:unity_shuffle_tests).and_return( true )
      allow(@generator).to receive(:generate_test_results)
      allow(@file_wrapper).to receive(:rm_f)

      expect(@loginator).to receive(:log)
        .with( /1 already up-to-date test executable/, Verbosity::NORMAL, LogLabels::NOTICE )

      @executor.stage_execute( @state )
    end

    it "does not log the shuffling NOTICE when :unity ↳ :shuffle_tests is enabled but the executable was already rebuilt (nothing to override)" do
      @testable.executable_rebuilt = true
      allow(@configurator).to receive(:unity_shuffle_tests).and_return( true )
      allow(@generator).to receive(:generate_test_results)
      allow(@file_wrapper).to receive(:rm_f)

      expect(@loginator).to_not receive(:log).with( /shuffl/i, any_args )

      @executor.stage_execute( @state )
    end

    it "does not log the shuffling NOTICE when :force_test_rerun (not shuffling) is what forces the rerun" do
      @testable.executable_rebuilt = false
      allow(@configurator).to receive(:force_test_rerun).and_return( true )
      allow(@generator).to receive(:generate_test_results)
      allow(@file_wrapper).to receive(:rm_f)

      expect(@loginator).to_not receive(:log).with( /shuffl/i, any_args )

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

    it "resolves the fixture tool through pre_test_fixture_register before registering staleness meta, and uses the resolved value for the real run" do
      @testable.executable_rebuilt = false

      swapped_tool = { name: 'fake valgrind wrapper' }
      allow(@plugin_manager).to receive(:pre_test_fixture_register) do |arg_hash|
        expect( arg_hash[:target] ).to eq( @fixture_target )
        arg_hash[:tool] = swapped_tool
      end

      expect(@dependinator).to receive(:register).with(
        @fixture_target,
        files: ['build/a_test.out'],
        meta:  { tools: [swapped_tool] }
      )
      expect(@generator).to receive(:generate_test_results) do |**args|
        expect( args[:tool] ).to eq( swapped_tool )
      end

      @executor.stage_execute( @state )
    end

    it "registers a dedicated marker target separate from the executable, with the executable as antecedent and the test fixture tool as meta" do
      @testable.executable_rebuilt = false
      allow(@generator).to receive(:generate_test_results)

      expect(@dependinator).to receive(:register).with(
        @fixture_target,
        files: ['build/a_test.out'],
        meta:  { tools: [@tools_test_fixture] }
      )

      @executor.stage_execute( @state )
    end

    it "reruns the test fixture when only the :tools ↳ :test_fixture configuration changed, even though the executable is unchanged" do
      @testable.executable_rebuilt = false
      allow(@dependinator).to receive(:stale?).with(@fixture_target).and_return( true )
      allow(@file_wrapper).to receive(:rm_f)

      expect(@file_wrapper).to receive(:rm_f).with( Dir.glob( File.join( 'build/test/results', 'a_test.*' ) ) )
      expect(@generator).to receive(:generate_test_results).with( hash_including( skipped: false ) )
      expect(@dependinator).to receive(:mark_fresh).with(@fixture_target)

      @executor.stage_execute( @state )
    end

    # The whole reason this target is a dedicated marker file rather than the test's own
    # outcome-dependent .pass/.fail result file: a failing test never writes the .pass
    # path, and DependencyTracker#mark_fresh would otherwise crash trying to hash a target
    # that doesn't exist -- exactly the CI failure this scenario guards against regressing.
    it "marks the marker target fresh after a real run even when the test itself fails" do
      @testable.executable_rebuilt = true
      allow(@file_wrapper).to receive(:rm_f)
      allow(@generator).to receive(:generate_test_results).and_return( { results: { counts: { failed: 1 } } } )

      expect(@file_wrapper).to receive(:touch).with(@fixture_target)
      expect(@dependinator).to receive(:mark_fresh).with(@fixture_target)

      @executor.stage_execute( @state )
    end

    it "does not mark the fixture target fresh when the run was skipped" do
      @testable.executable_rebuilt = false
      allow(@generator).to receive(:generate_test_results)

      expect(@dependinator).to_not receive(:mark_fresh)

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

    it "registers the bare-includes and directives-only preprocessor tools, and the fallback setting, as meta" do
      allow(@preprocessinator).to receive(:preprocess_mockable_header_file)

      expect(@dependinator).to receive(:register).with(
        'build/preprocess/MockFoo.h',
        files: ['src/Foo.h'],
        meta:  {
          flags: [], defines: [], search_paths: [], extras: false,
          tools: [@tools_test_bare_includes_preprocessor, @tools_test_file_directives_only_preprocessor],
          preprocess_force_fallback: false
        }
      )

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

    it "validates a test's TEST_SOURCE_FILE() entries through the resolver, regardless of staleness" do
      allow(@dependinator).to receive(:stale?).and_return( false )

      expect(@test_source_file_directive_resolver).to receive(:validate!).with( test: 'a_test', filepath: 'test/TestFoo.c' )

      @executor.stage_preprocess_test_files( @state )
    end
  end

  context "#tailor_search_paths" do
    PROJECT_BUILD_VENDOR_CMOCK_PATH      = 'build/vendor/cmock'      unless defined?(PROJECT_BUILD_VENDOR_CMOCK_PATH)
    PROJECT_BUILD_VENDOR_CEXCEPTION_PATH = 'build/vendor/cexception' unless defined?(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH)

    before(:each) do
      allow(@configurator).to receive(:collection_paths_support).and_return( ['support'] )
    end

    it "returns the given search paths unchanged for an ordinary test source" do
      result = @executor.send( :tailor_search_paths, filepath: 'src/Foo.c', search_paths: ['src', 'test'] )

      expect(result).to eq( ['src', 'test'] )
    end

    it "swaps in the support paths plus Unity's own vendor path for Unity's own source" do
      filepath = File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq( ['support', PROJECT_BUILD_VENDOR_UNITY_PATH] )
    end

    it "swaps in the support, Unity, and CMock vendor paths for CMock's own source when mocks are in use" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      filepath = File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq( ['support', PROJECT_BUILD_VENDOR_UNITY_PATH, PROJECT_BUILD_VENDOR_CMOCK_PATH] )
    end

    it "also folds in the CException vendor path for CMock's own source when exceptions are also in use" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:project_use_exceptions).and_return( true )
      filepath = File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq(
        ['support', PROJECT_BUILD_VENDOR_UNITY_PATH, PROJECT_BUILD_VENDOR_CMOCK_PATH, PROJECT_BUILD_VENDOR_CEXCEPTION_PATH]
      )
    end

    it "leaves CMock's own source untouched when mocks are not in use, falling through to the given search paths" do
      filepath = File.join( PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq( ['src', 'test'] )
    end

    it "swaps in the support and CException vendor paths for CException's own source when exceptions are in use" do
      allow(@configurator).to receive(:project_use_exceptions).and_return( true )
      filepath = File.join( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq( ['support', PROJECT_BUILD_VENDOR_CEXCEPTION_PATH] )
    end

    it "adds the support and every in-use framework's own vendor path for a support file" do
      allow(@configurator).to receive(:project_use_mocks).and_return( true )
      allow(@configurator).to receive(:project_use_exceptions).and_return( true )
      allow(@configurator).to receive(:collection_all_support).and_return( ['test/support/CustomAsserts.c'] )

      result = @executor.send( :tailor_search_paths, filepath: 'test/support/CustomAsserts.c', search_paths: ['src', 'test'] )

      expect(result).to eq(
        ['src', 'test', 'support', PROJECT_BUILD_VENDOR_UNITY_PATH, PROJECT_BUILD_VENDOR_CMOCK_PATH, PROJECT_BUILD_VENDOR_CEXCEPTION_PATH]
      )
    end

    it "deduplicates the tailored search paths it assembles" do
      allow(@configurator).to receive(:collection_paths_support).and_return( ['support', PROJECT_BUILD_VENDOR_UNITY_PATH] )
      filepath = File.join( PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE )

      result = @executor.send( :tailor_search_paths, filepath: filepath, search_paths: ['src', 'test'] )

      expect(result).to eq( ['support', PROJECT_BUILD_VENDOR_UNITY_PATH] )
    end
  end

end
