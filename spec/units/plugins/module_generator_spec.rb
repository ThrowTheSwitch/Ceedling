# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'

[File.expand_path( '../../../plugins/module_generator/lib', __dir__ ),
 File.expand_path( '../../../vendor/unity/auto', __dir__ ),
 File.expand_path( '../../../vendor/cmock/lib', __dir__ )].each { |path| $LOAD_PATH.unshift( path ) unless $LOAD_PATH.include?( path ) }

require 'module_generator'
require 'generate_module'
require 'cmock'
require 'module_generator_unity'

# The plugin hands each request to Unity's module generator or CMock's skeleton
# generator. Both are doubled here, so nothing touches the filesystem.
describe ModuleGenerator do

  let(:config) do
    { collection_paths_source: ['src', 'src/lab'], collection_paths_include: ['inc'], collection_paths_test: ['test'],
      project_test_file_prefix: 'test_', cmock_mock_prefix: 'mock_' }
  end

  let(:configurator)       { double( 'configurator', project_config_hash: config, get_cmock_config: { mock_prefix: 'mock_' } ) }
  let(:file_finder_helper) { double( 'file_finder_helper' ) }
  let(:file_wrapper)       { double( 'file_wrapper' ) }
  let(:loginator)          { double( 'loginator' ) }
  let(:unity)              { double( 'unity_module_generator' ) }
  let(:cmock)              { double( 'cmock' ) }

  let(:plugin) do
    described_class.new(
      { configurator: configurator, file_finder_helper: file_finder_helper, file_wrapper: file_wrapper, loginator: loginator },
      'module_generator', '/plugins/module_generator'
    )
  end

  def request(name, path_hint: nil, pattern: nil)
    return ModuleGeneratorRequest.new( name: name, path_hint: path_hint, pattern: pattern )
  end

  it 'reports the configured test file prefix' do
    expect(plugin.test_prefix).to eq( 'test_' )
  end

  it 'creates a module with the options built for its request' do
    expect(ModuleGeneratorUnity).to receive(:new).with( hash_including( pattern: 'mch', path_src: 'src' ) ).and_return( unity )
    expect(unity).to receive(:generate).with( 'Lair' )

    plugin.create( request( 'Lair', pattern: 'mch' ) )
  end

  it 'destroys a module with the options built for its request' do
    expect(ModuleGeneratorUnity).to receive(:new).with( hash_including( path_src: 'src' ) ).and_return( unity )
    expect(unity).to receive(:destroy).with( 'Lair' )

    plugin.destroy( request( 'Lair' ) )
  end

  it 'matches a hint through the path finder' do
    allow(file_finder_helper).to receive(:find_best_path_in_collection) { |_hint, paths| paths.last }
    expect(ModuleGeneratorUnity).to receive(:new).with( hash_including( path_src: 'src/lab' ) ).and_return( unity )
    allow(unity).to receive(:generate)

    plugin.create( request( 'Lair', path_hint: 'lab' ) )
  end

  it 'reads a list the path finder finds no match in as unmatched' do
    allow(file_finder_helper).to receive(:find_best_path_in_collection).and_raise( CeedlingException.new( 'Found no path' ) )

    expect { plugin.create( request( 'Lair', path_hint: 'bad' ) ) }.to raise_error( CeedlingException, /`bad` matches no/ )
  end

  it 'reads boilerplate files through the file wrapper' do
    config[:module_generator_boilerplate_files] = { src: 'bp.txt' }
    allow(file_wrapper).to receive(:exist?).with( 'bp.txt' ).and_return( true )
    allow(file_wrapper).to receive(:read).with( 'bp.txt' ).and_return( '/* bp */' )
    expect(ModuleGeneratorUnity).to receive(:new).with( hash_including( boilerplates: hash_including( src: '/* bp */' ) ) ).and_return( unity )
    allow(unity).to receive(:generate)

    plugin.create( request( 'Lair' ) )
  end

  it 'warns that :update_svn is deprecated when it is configured' do
    config[:module_generator_update_svn] = true
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:generate)
    expect(loginator).to receive(:log).with( /:update_svn.*deprecated/, Verbosity::COMPLAIN, LogLabels::WARNING )

    plugin.create( request( 'Lair' ) )
  end

  it 'says nothing about :update_svn when it is not configured' do
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:generate)
    expect(loginator).not_to receive(:log)

    plugin.create( request( 'Lair' ) )
  end

  it 'stubs a header through CMock with the skeleton beside the source' do
    expect(CMock).to receive(:new).with( hash_including( mock_prefix: 'mock_', skeleton_path: 'src' ) ).and_return( cmock )
    expect(cmock).to receive(:setup_skeletons).with( 'inc/stubby.h' )

    plugin.stub( request( 'stubby' ) )
  end

end
