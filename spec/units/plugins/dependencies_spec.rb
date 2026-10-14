# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/filename_extension'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/dependencies/lib', __dir__ ) )

require 'dependencies'

# The plugin's orchestration of fetching, building, cleaning, and deploying. Every tool,
# file, and directory operation is doubled: `files` holds the directories that exist and
# their entries, and commands are recorded rather than run.
describe Dependencies do

  let(:files)    { {} }
  let(:executed) { [] }
  let(:logged)   { [] }

  let(:tool_executor) do
    double( 'tool_executor' ).tap do |executor|
      allow(executor).to receive(:build_command_line) { |tool, extra, *args| { line: [tool[:name], *extra, *args].join( ' ' ) } }
      allow(executor).to receive(:exec) { |command| executed << command[:line] }
    end
  end

  let(:file_wrapper) do
    double( 'file_wrapper' ).tap do |wrapper|
      allow(wrapper).to receive(:directory?) { |path| files.key?( path ) }
      allow(wrapper).to receive(:exist?) { |path| files.key?( path ) or files.values.flatten.include?( path ) }
      allow(wrapper).to receive(:directory_entries) { |path| files.fetch( path, [] ) }
      allow(wrapper).to receive(:mkdir) { |path| files[path] ||= [] }
      allow(wrapper).to receive(:directory_listing) { [] }
      allow(wrapper).to receive(:rm_rf)
      allow(wrapper).to receive(:cp)
    end
  end

  let(:generator) { double( 'generator', generate_object_file_c: nil, generate_executable_file: nil ) }

  let(:objects) do
    { tool_executor: tool_executor, file_wrapper: file_wrapper, generator: generator,
      tool_validator: double( 'tool_validator', validate: true ),
      loginator: double( 'loginator', lazy: nil ).tap { |log| allow(log).to receive(:log) { |message, *| logged << message } },
      file_path_collection_utils: double( 'file_path_collection_utils', collect_paths: [] ),
      file_path_utils: double( 'file_path_utils', form_release_build_list_filepath: 'list', form_test_build_map_filepath: 'map' ) }
  end

  def dependency(name = 'dep', **overrides)
    return {
      name: name, paths: { fetch: "deps/#{name}", build: "deps/#{name}/build" },
      fetch: { method: :git, source: 'url' }, build: ['make'],
      artifacts: { static_libraries: ["lib#{name}.a"] }
    }.merge( overrides )
  end

  def plugin_for(*deps)
    stub_const( 'DEPENDENCIES_DEPS', deps )
    %w[ZIP TARGZIP GIT_CLONE GIT_CHECKOUT SUBVERSION COMPILER LINKER].each { |tool| stub_const( "TOOLS_DEPS_#{tool}", { name: tool.downcase } ) }
    stub_const( 'PROJECT_RELEASE_BUILD_TARGET', 'build/release/app.out' )
    stub_const( 'EXTENSION_SOURCE', FilenameExtension.new( '.c' ) )
    stub_const( 'EXTENSION_HEADER', FilenameExtension.new( '.h' ) )
    stub_const( 'EXTENSION_OBJECT', FilenameExtension.new( '.o' ) )
    stub_const( 'EXTENSION_ASSEMBLY', FilenameExtension.new( [] ) )

    plugin = described_class.new( objects, 'dependencies', '/plugins/dependencies' )
    allow(plugin).to receive(:in_directory) { |path, &block| executed << "cd #{path}"; block.call }
    return plugin
  end

  describe 'fetching' do
    it 'runs the fetch commands in the fetch path, creating it' do
      plugin_for( dependency ).fetch_if_required( 'dep' )

      expect(executed).to eq( ['cd deps/dep', 'git_clone  --depth 1 url'] )
      expect(files).to include( 'deps/dep' )
    end

    it 'skips a dependency whose fetch path already holds files' do
      files['deps/dep'] = ['README']
      plugin_for( dependency ).fetch_if_required( 'dep' )

      expect(executed).to be_empty
      expect(logged.join).to include( 'already fetched' )
    end

    it 'fetches into an empty fetch path' do
      files['deps/dep'] = []
      plugin_for( dependency ).fetch_if_required( 'dep' )

      expect(executed).to include( 'git_clone  --depth 1 url' )
    end

    it 'fetches nothing for a dependency without a fetch method' do
      plugin_for( dependency( fetch: nil ) ).fetch_if_required( 'dep' )

      expect(executed).to be_empty
    end

    it 'fetches nothing, and creates nothing, for a dependency fetched by :none' do
      plugin_for( dependency( fetch: { method: :none } ) ).fetch_if_required( 'dep' )

      expect(executed).to be_empty
      expect(file_wrapper).not_to have_received(:mkdir)
    end
  end

  describe 'making' do
    it 'fetches, then runs build commands in the source path' do
      plugin_for( dependency ).make_if_required( 'dep' )

      expect(executed).to eq( ['cd deps/dep', 'git_clone  --depth 1 url', 'cd deps/dep', 'make'] )
    end

    it 'builds a dependency fetched beforehand without fetching it again' do
      files['deps/dep'] = ['makefile']
      plugin_for( dependency ).make_if_required( 'dep' )

      expect(executed).to eq( ['cd deps/dep', 'make'] )
    end

    it 'creates the source, build, and artifact paths a build writes into' do
      plugin_for( dependency( fetch: { method: :none }, paths: { source: 's', build: 's/b', artifact: 's/a' } ) ).make_if_required( 'dep' )

      expect(files.keys).to include( 's', 's/b', 's/a' )
    end

    it 'refuses a build step it does not know' do
      expect { plugin_for( dependency( build: [:build_everything] ) ).make_if_required( 'dep' ) }
        .to raise_error( CeedlingException, /build_everything.*dep/ )
    end
  end

  describe 'cleaning' do
    it 'removes every working path of a fetched dependency' do
      files['deps/dep'] = files['deps/dep/build'] = []
      plugin_for( dependency ).clean_if_required( 'dep' )

      expect(file_wrapper).to have_received(:rm_rf).with( 'deps/dep' )
      expect(file_wrapper).to have_received(:rm_rf).with( 'deps/dep/build' )
    end

    it 'removes only the artifacts of a dependency that is not fetched' do
      files['mine'] = files['mine/out'] = []
      plugin_for( dependency( fetch: { method: :none }, paths: { source: 'mine', artifact: 'mine/out' } ) ).clean_if_required( 'dep' )

      expect(file_wrapper).to have_received(:rm_rf).with( 'mine/out' ).once
      expect(file_wrapper).not_to have_received(:rm_rf).with( 'mine' )
    end

    it 'removes nothing for a dependency without a fetch method' do
      plugin_for( dependency( fetch: nil ) ).clean_if_required( 'dep' )

      expect(file_wrapper).not_to have_received(:rm_rf)
    end
  end

  describe 'deploying' do
    let(:shared) { dependency( artifacts: { dynamic_libraries: ['libone.so', 'libtwo.so'] } ) }

    it 'copies every dynamic library from the artifact path beside the release build' do
      files['deps/dep/build'] = ['deps/dep/build/libone.so', 'deps/dep/build/libtwo.so']
      plugin_for( shared ).deploy_if_required( 'dep' )

      expect(file_wrapper).to have_received(:mkdir).with( 'build/release' )
      expect(file_wrapper).to have_received(:cp).with( 'deps/dep/build/libone.so', 'build/release' )
      expect(file_wrapper).to have_received(:cp).with( 'deps/dep/build/libtwo.so', 'build/release' )
    end

    it 'refuses to deploy a dynamic library that was not built' do
      expect { plugin_for( shared ).deploy_if_required( 'dep' ) }.to raise_error( CeedlingException, %r{deps/dep/build/libone.so} )
    end

    it 'deploys nothing for a dependency without dynamic libraries' do
      plugin_for( dependency ).deploy_if_required( 'dep' )

      expect(file_wrapper).not_to have_received(:cp)
    end
  end

  describe 'libraries' do
    it 'names every library and its directory for linking' do
      plugin = plugin_for( dependency( artifacts: { static_libraries: ['libw.a'], dynamic_libraries: ['sub/libv.so'] } ) )

      expect(plugin.link_libraries).to eq( names: ['w', 'v'], paths: ['deps/dep/build', 'deps/dep/build/sub'] )
    end
  end

  describe ':build_lib' do
    let(:lib) { dependency( fetch: { method: :none }, paths: { source: 'cc', build: 'cc/build', artifact: 'cc/out' },
                            build: [:build_lib], defines: ['FAST'], artifacts: { static_libraries: ['libcc.a'] } ) }

    before(:each) do
      allow(file_wrapper).to receive(:directory_listing) do |glob|
        { 'cc/**/*.c' => ['cc/a.c', 'cc/src/b.c'], 'cc/**/*.h' => ['cc/inc/a.h'] }.fetch( glob, [] )
      end
    end

    it 'compiles each source with the header directories and defines, outside any build directory' do
      plugin_for( lib ).make_if_required( 'dep' )

      expect(generator).to have_received(:generate_object_file_c)
        .with( hash_including( source: 'cc/src/b.c', object: 'cc/build/b.o', search_paths: ['cc/inc'], defines: ['FAST'] ) )
      expect(executed).not_to include( a_string_starting_with( 'cd ' ) )
    end

    it 'archives the objects into the first static library, then copies it to the artifact path' do
      plugin_for( lib ).make_if_required( 'dep' )

      expect(generator).to have_received(:generate_executable_file)
        .with( anything, anything, ['cc/build/a.o', 'cc/build/b.o'], [], 'cc/build/libcc.a', 'map', [], [] )
      expect(file_wrapper).to have_received(:cp).with( 'cc/build/libcc.a', 'cc/out/libcc.a' )
    end

    it 'refuses to build without a static library to build' do
      lib[:artifacts] = { dynamic_libraries: ['libcc.so'] }

      expect { plugin_for( lib ).make_if_required( 'dep' ) }.to raise_error( CeedlingException, /:static_libraries/ )
    end
  end

end
