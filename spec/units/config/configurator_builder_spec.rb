# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


#derived from test_graveyard/unit/busted/configurator_builder_test.rb

require 'spec_helper'
require 'ceedling/config/configurator_builder'
require 'ceedling/filename_extension'
require 'ceedling/system_utils' # Object#deep_clone
require 'ceedling/system_wrapper'
require 'ceedling/constants'

describe ConfiguratorBuilder do

  describe '#populate_with_defaults' do
    let(:builder) { ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil) }

    it 'copies in a missing Hash default as an unfrozen, independent clone' do
      default_tool = { :executable => 'gcc'.freeze, :arguments => ['-g'.freeze].freeze }.freeze
      defaults = { :tools => { :some_tool => default_tool } }
      config = { :tools => {} }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to_not be_frozen
      expect(config[:tools][:some_tool][:arguments].first).to_not be_frozen
      expect(config[:tools][:some_tool][:executable]).to_not equal(default_tool[:executable])
    end

    # This is the actual gap: a project.yml that partially defines a tool already
    # present as a Hash (e.g. one plugin-config key alongside a plugin-default-only
    # tool) recurses into that existing sub-hash rather than copying it in wholesale
    # -- any of its own still-missing String/Array leaf values were, before this fix,
    # assigned by direct reference to the (often frozen, plugin-literal) default
    # value, rather than cloned the same way a wholesale-missing tool already was.
    it 'clones a String/Array leaf default even when only recursing into an already-present Hash' do
      default_tool = { :executable => 'gcc'.freeze, :arguments => ['-g'.freeze].freeze }.freeze
      defaults = { :tools => { :some_tool => default_tool } }
      config = { :tools => { :some_tool => { :ceedling_delta_probe => true } } }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to eq('gcc')
      expect(config[:tools][:some_tool][:executable]).to_not be_frozen
      expect(config[:tools][:some_tool][:arguments]).to eq(['-g'])
      expect(config[:tools][:some_tool][:arguments].first).to_not be_frozen
      expect(config[:tools][:some_tool][:ceedling_delta_probe]).to be(true)
    end

    it 'leaves an already-present value untouched rather than overwriting it with the default' do
      defaults = { :tools => { :some_tool => { :executable => 'gcc' } } }
      config = { :tools => { :some_tool => { :executable => 'clang' } } }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to eq('clang')
    end
  end

  describe '#normalize_filename_extensions' do
    let(:builder) { ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil) }

    it 'wraps every :extension child value in a FilenameExtension' do
      config = { extension: { source: '.c', assembly: ['.s', '.S'] } }
      builder.normalize_filename_extensions(config)

      expect(config[:extension][:source]).to be_a(FilenameExtension)
      expect(config[:extension][:source].to_a).to eq(['.c'])
      expect(config[:extension][:assembly]).to be_a(FilenameExtension)
      expect(config[:extension][:assembly].to_a).to eq(['.s', '.S'])
    end

    it 'does nothing when config has no :extension entry at all' do
      config = {}
      expect { builder.normalize_filename_extensions(config) }.not_to raise_error
      expect(config[:extension]).to be_nil
    end
  end

  # A FileList stand-in that records the glob patterns a collection asks for, so a unit
  # spec can read which files a collection would gather without a filesystem
  class RecordingFileList
    attr_reader :patterns, :excluded

    def initialize(found = [])
      @found    = found
      @patterns = []
      @excluded = []
    end

    def include(*patterns) = @patterns.concat( patterns )
    def exclude(*files)    = @excluded.concat( files )
    def resolve()          = self
    def include?(file)     = @found.include?( file )
    def each(&block)       = @found.each( &block )
  end

  describe 'built values' do
    before(:each) do
      @collection_utils = double('file_path_collection_utils')
      @file_wrapper     = double('file_wrapper')
      @loginator        = double('loginator', log: nil)
      @builder = ConfiguratorBuilder.new(
        file_path_collection_utils: @collection_utils, loginator: @loginator, file_wrapper: @file_wrapper,
        system_wrapper: double('system_wrapper', processor_count: 8)
      )
    end

    let(:extensions) do
      {
        extension_source:     FilenameExtension.new('.c'),
        extension_header:     FilenameExtension.new('.h'),
        extension_assembly:   FilenameExtension.new(['.s', '.S']),
        extension_object:     FilenameExtension.new('.o'),
        extension_executable: FilenameExtension.new('.out'),
        extension_map:        FilenameExtension.new('.map')
      }
    end

    describe '#flattenify' do
      it 'joins each section and child key into one top-level key' do
        config = { project: { build_root: 'build', use_mocks: true }, unity: { defines: ['X'] } }

        expect(@builder.flattenify( config )).to eq( project_build_root: 'build', project_use_mocks: true, unity_defines: ['X'] )
      end

      it 'flattens a list of single-pair hashes by each pair' do
        expect(@builder.flattenify( { environment: [ { path: 'a' }, { cc: 'gcc' } ] } )).to eq( environment_path: 'a', environment_cc: 'gcc' )
      end

      it 'keeps a section that holds a plain value under its own name' do
        expect(@builder.flattenify( { Version: '1.0' } )).to eq( version: '1.0' )
      end

      it 'skips an empty section' do
        expect(@builder.flattenify( { project: nil } )).to eq( {} )
      end
    end

    describe '#set_build_paths' do
      let(:in_hash) do
        {
          project_build_root: 'build', project_release_build: false, project_use_mocks: true,
          project_use_exceptions: false, project_use_test_preprocessor: :none, project_use_partials: false,
          cmock_mock_path: 'build/test/mocks'
        }
      end

      it 'derives every build path from the build root' do
        paths = @builder.set_build_paths( in_hash, 'build/logs' )

        expect(paths).to include(
          project_build_artifacts_root:          'build/artifacts',
          project_test_runners_path:             'build/test/runners',
          project_build_vendor_unity_path:       'build/vendor/unity/src',
          project_build_vendor_cmock_path:       'build/vendor/cmock/src',
          project_log_path:                      'build/logs',
          project_build_dependencies_cache_path: 'build/cache'
        )
      end

      it 'lists for creation only the directories the configured features use' do
        build_paths = @builder.set_build_paths( in_hash, 'build/logs' )[:project_build_paths]

        expect(build_paths).to include('build/test/mocks', 'build/vendor/cmock/src', 'build/test/preprocess/build_directives')
        expect(build_paths).to_not include('build/release', 'build/vendor/c_exception/lib', 'build/test/preprocess/files', 'build/test/partials')
      end

      it 'adds release, exception, preprocessing, and Partials directories when enabled' do
        enabled = in_hash.merge( project_release_build: true, project_use_exceptions: true, project_use_test_preprocessor: :all, project_use_partials: true )
        build_paths = @builder.set_build_paths( enabled, 'build/logs' )[:project_build_paths]

        expect(build_paths).to include('build/release', 'build/vendor/c_exception/lib', 'build/test/preprocess/files', 'build/test/partials')
      end
    end

    describe '#set_rakefile_components' do
      it 'loads the release Rakefiles only for a release build' do
        test_only = @builder.set_rakefile_components( 'lib', { project_release_build: false } )[:project_rakefile_component_files]
        release   = @builder.set_rakefile_components( 'lib', { project_release_build: true } )[:project_rakefile_component_files]

        expect(release - test_only).to eq( RakefileComponentResolver.release_rakefiles( 'lib' ) )
        expect(test_only).to eq( RakefileComponentResolver.base_rakefiles( 'lib' ) + RakefileComponentResolver.test_rakefiles( 'lib' ) )
      end
    end

    describe '#set_release_target' do
      let(:in_hash) { extensions.merge( project_release_build: true, project_build_release_root: 'build/release' ) }

      it 'is empty without a release build' do
        expect(@builder.set_release_target( { project_release_build: false } )).to eq( {} )
      end

      it 'names the default target and map file by the configured extensions' do
        expect(@builder.set_release_target( in_hash.merge( release_build_output: nil ) )).to eq(
          project_release_build_target: 'build/release/project.out', project_release_build_map: 'build/release/project.map'
        )
      end

      it 'names the map file after a configured target' do
        expect(@builder.set_release_target( in_hash.merge( release_build_output: 'app.elf' ) )).to eq(
          project_release_build_target: 'build/release/app.elf', project_release_build_map: 'build/release/app.map'
        )
      end
    end

    describe '#set_build_thread_counts' do
      it 'keeps an explicit count' do
        expect(@builder.set_build_thread_counts( { project_compile_threads: 3, project_test_threads: 1 } )).to eq(
          project_compile_threads: 3, project_test_threads: 1
        )
      end

      it 'resolves :auto to the processor count plus four' do
        expect(@builder.set_build_thread_counts( { project_compile_threads: :auto, project_test_threads: :auto } )).to eq(
          project_compile_threads: 12, project_test_threads: 12
        )
      end
    end

    describe '#set_test_preprocessor_accessors' do
      {
        none:  [false, false],
        all:   [true,  true],
        tests: [true,  false],
        mocks: [false, true]
      }.each do |option, (tests, mocks)|
        it "splits :#{option} into whether tests and mocks are preprocessed" do
          expect(@builder.set_test_preprocessor_accessors( { project_use_test_preprocessor: option } )).to eq(
            project_use_test_preprocessor_tests: tests, project_use_test_preprocessor_mocks: mocks
          )
        end
      end
    end

    describe 'path collections' do
      let(:in_hash) do
        {
          collection_paths_test: ['test'], collection_paths_support: ['test/support'],
          collection_paths_source: ['src'], collection_paths_include: ['inc'],
          project_build_vendor_unity_path: 'v/unity', project_build_vendor_cmock_path: 'v/cmock',
          project_build_vendor_cexception_path: 'v/cexception', project_build_vendor_ceedling_path: 'v/ceedling',
          project_use_mocks: true, project_use_exceptions: false, project_use_partials: false
        }
      end

      it 'expands each :paths entry into a collection' do
        allow(@collection_utils).to receive(:collect_paths) { |paths| paths.map { |p| p.delete_suffix('/**') } }

        expect(@builder.expand_all_path_globs( { paths_test: ['test/**'], paths_source: ['src'], project_build_root: 'build' } )).to eq(
          collection_paths_test: ['test'], collection_paths_source: ['src']
        )
      end

      it 'combines source and include paths' do
        expect(@builder.collect_source_and_include_paths( in_hash )).to eq( collection_paths_source_and_include: ['src', 'inc'] )
      end

      it 'adds the CException and Ceedling vendor paths to sources and includes as features need them' do
        hash = in_hash.merge( collection_paths_source_and_include: ['src', 'inc'], project_use_exceptions: true, project_use_partials: true )

        expect(@builder.collect_source_include_vendor_paths( hash )).to eq(
          collection_paths_source_include_vendor: ['src', 'inc', 'v/cexception', 'v/ceedling']
        )
      end

      it 'combines test, support, source, and include paths' do
        expect(@builder.collect_test_support_source_include_paths( in_hash )).to eq(
          collection_paths_test_support_source_include: ['test', 'test/support', 'src', 'inc']
        )
      end

      it 'lists vendor paths for the frameworks in use' do
        expect(@builder.collect_vendor_paths( in_hash )).to eq( collection_paths_vendor: ['v/unity', 'v/cmock'] )
      end

      it 'puts vendor paths ahead of test, support, source, and include paths' do
        hash = in_hash.merge( collection_paths_test_support_source_include: ['test', 'src'] )

        expect(@builder.collect_test_support_source_include_vendor_paths( hash )).to eq(
          collection_paths_test_support_source_include_vendor: ['v/unity', 'v/cmock', 'test', 'src']
        )
      end
    end

    describe 'file collections' do
      let(:in_hash) do
        extensions.merge(
          collection_paths_test: ['test'], collection_paths_support: ['support'], collection_paths_source: ['src'],
          collection_paths_include: ['inc'], project_test_file_prefix: 'test_',
          project_build_vendor_unity_path: 'v/unity', project_build_vendor_cmock_path: 'v/cmock',
          project_build_vendor_cexception_path: 'v/cexception', project_build_vendor_ceedling_path: 'v/ceedling',
          project_use_mocks: false, project_use_exceptions: false, project_use_partials: false,
          test_build_use_assembly: false, release_build_use_assembly: false,
          files_test: ['+:extra/test_x.c'], files_support: [], files_source: ['-:src/skip.c'], files_include: [], files_assembly: ['+:a.s']
        )
      end

      # Each collection's FileList, and the revisions applied to it
      def collect(found = [])
        lists = []
        allow(@file_wrapper).to receive(:instantiate_file_list) { (lists << RecordingFileList.new( found )).last }
        allow(@collection_utils).to receive(:revise_filelist) { |list, revisions| [list, revisions] }
        result = yield
        return result, lists
      end

      it 'collects tests by test-file prefix and revises them by :files ↳ :test' do
        (collection, list), = collect { @builder.collect_tests( in_hash ) }
        file_list, revisions = list

        expect(collection[:collection_all_tests]).to eq( list )
        expect(file_list.patterns).to eq( ['test/test_*.c'] )
        expect(revisions).to eq( ['+:extra/test_x.c'] )
      end

      it 'collects no assembly when neither build uses it' do
        result, lists = collect { @builder.collect_assembly( in_hash ) }

        expect(result[:collection_all_assembly]).to equal( lists.first )
        expect(lists.first.patterns).to eq( [] )
      end

      it 'collects assembly from source and support paths when a build uses it' do
        result, = collect { @builder.collect_assembly( in_hash.merge( test_build_use_assembly: true ) ) }
        file_list, revisions = result[:collection_all_assembly]

        expect(file_list.patterns).to eq( ['src/*.s', 'src/*.S', 'support/*.s', 'support/*.S'] )
        expect(revisions).to eq( ['+:a.s'] )
      end

      it 'collects sources, filtering out tests that overlapping paths also matched' do
        result, = collect( ['src/a.c', 'src/test_a.c'] ) { @builder.collect_source( in_hash, ['src/test_a.c'] ) }
        file_list, revisions = result[:collection_all_source]

        expect(file_list.patterns).to eq( ['src/*.c'] )
        expect(file_list.excluded).to eq( ['src/test_a.c'] )
        expect(revisions).to eq( ['-:src/skip.c'] )
        expect(@loginator).to have_received(:log).with(/overlap/, Verbosity::COMPLAIN)
      end

      it 'collects headers from test, support, and include paths' do
        result, = collect { @builder.collect_headers( in_hash ) }

        expect(result[:collection_all_headers].first.patterns).to eq( ['test/*.h', 'support/*.h', 'inc/*.h'] )
      end

      it 'collects release input from sources, plus assembly and CException when in use' do
        hash = in_hash.merge( release_build_use_assembly: true, project_use_exceptions: true )
        result, = collect { @builder.collect_release_build_input( hash ) }
        file_list, revisions = result[:collection_release_build_input]

        expect(file_list.patterns).to eq( ['v/cexception/*.c', 'src/*.c', 'src/*.s', 'src/*.S'] )
        expect(revisions).to eq( ['-:src/skip.c', '+:a.s'] )
      end

      it 'collects existing test build input from vendor, test, support, and source paths' do
        result, = collect { @builder.collect_existing_test_build_input( in_hash.merge( project_use_mocks: true ) ) }
        file_list, revisions = result[:collection_existing_test_build_input]

        expect(file_list.patterns).to eq( ['v/unity/*.c', 'v/cmock/*.c', 'test/*.c', 'support/*.c', 'src/*.c'] )
        expect(revisions).to eq( ['+:extra/test_x.c', '-:src/skip.c'] )
      end

      it 'links CException into a release only when exceptions are in use' do
        expect(@builder.collect_release_artifact_extra_link_objects( in_hash )).to eq( collection_release_artifact_extra_link_objects: [] )
        expect(@builder.collect_release_artifact_extra_link_objects( in_hash.merge( project_use_exceptions: true ) )).to eq(
          collection_release_artifact_extra_link_objects: ['CException.o']
        )
      end

      it 'links every support source into each test fixture as an object' do
        allow(@file_wrapper).to receive(:instantiate_file_list).and_return(RecordingFileList.new)
        allow(@collection_utils).to receive(:revise_filelist).and_return(['support/helper.c', 'support/deep/stub.c'])

        expect(@builder.collect_test_fixture_extra_link_objects( in_hash )).to eq(
          collection_all_support: ['support/helper.c', 'support/deep/stub.c'],
          collection_test_fixture_extra_link_objects: ['helper.o', 'stub.o']
        )
      end

      it 'names the vendor framework sources without their paths' do
        allow(@file_wrapper).to receive(:instantiate_file_list).and_return(RecordingFileList.new( ['v/unity/unity.c'] ))

        expect(@builder.collect_vendor_framework_sources( in_hash )).to eq( collection_vendor_framework_sources: ['unity.c'] )
      end
    end
  end

  # Constants go into an injected namespace, so a spec never touches Object
  describe 'constants and accessors' do
    let(:namespace) { Module.new }
    let(:builder) do
      builder = ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil)
      builder.constants_namespace = namespace
      builder
    end

    it 'names a constant by upcasing its key and replacing dashes' do
      builder.build_global_constant( :'configurator_spec_c-file', 'x.c' )

      expect(namespace.const_get( :CONFIGURATOR_SPEC_C_FILE )).to eq( 'x.c' )
      expect(Object.const_defined?( :CONFIGURATOR_SPEC_C_FILE )).to be false
    end

    it 'replaces a constant that already exists' do
      builder.build_global_constant( :configurator_spec_value, 1 )
      builder.build_global_constant( :configurator_spec_value, 2 )

      expect(namespace.const_get( :CONFIGURATOR_SPEC_VALUE )).to eq( 2 )
    end

    it 'defines empty assembler tool constants for builds that do not assemble' do
      builder.build_global_constants( { test_build_use_assembly: false, release_build_use_assembly: true } )

      expect(namespace.const_get( :TOOLS_TEST_ASSEMBLER )).to eq( {} )
      expect(namespace.const_defined?( :TOOLS_RELEASE_ASSEMBLER, false )).to be false
    end

    it 'defines in the build namespace by default' do
      expect(ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil)
        .instance_variable_get( :@constants_namespace )).to equal( Object )
    end

    it 'defines an accessor on the target alone for each key, reading the project configuration' do
      target = Object.new
      target.instance_variable_set( :@project_config_hash, { configurator_spec_key: 7 } )

      builder.build_accessor_methods( { configurator_spec_key: 7 }, target )

      expect(target.configurator_spec_key).to eq( 7 )
      expect(Object.new).to_not respond_to( :configurator_spec_key )
    end

    it 'defines a working accessor for a key containing a dash' do
      target = Object.new
      target.instance_variable_set( :@project_config_hash, { 'configurator_spec-file': 'x.c' } )

      builder.build_accessor_methods( { 'configurator_spec-file': 'x.c' }, target )

      expect(target.configurator_spec_file).to eq( 'x.c' )
    end
  end
end
