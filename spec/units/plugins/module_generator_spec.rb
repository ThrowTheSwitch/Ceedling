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
require 'pathname'

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
  let(:loginator)          { double( 'loginator', log: nil ) }
  let(:defineinator)       { double( 'defineinator' ) }

  # Test defines as a build resolves them for each test file, TEST unless a spec says otherwise
  let(:resolved_defines)   { Hash.new( ['TEST'] ) }
  let(:unity)              { double( 'unity_module_generator', files_to_operate_on: [] ) }
  let(:cmock)              { double( 'cmock' ) }

  let(:plugin) do
    described_class.new(
      { configurator: configurator, file_finder_helper: file_finder_helper, file_wrapper: file_wrapper, loginator: loginator, defineinator: defineinator },
      'module_generator', '/plugins/module_generator'
    )
  end

  # A real generator reaching the disk is a broken stub, so it fails loudly instead
  before(:each) do
    allow(defineinator).to receive(:defines) { |subkey:, filepath:| subkey == :test ? resolved_defines[filepath] : [] }
    %i[generate destroy].each do |method|
      allow_any_instance_of( UnityModuleGenerator ).to receive( method ).and_raise( 'Unit specs must not write module files' )
    end
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

  def planned_test(path)
    return { path: Pathname.new( path ), test_define: 'TEST' }
  end

  it 'warns about each generated test file its test define does not reach' do
    resolved_defines['test/test_Lair.c'] = ['OTHER']
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:files_to_operate_on).with( 'Lair' ).and_return( [{ path: Pathname.new( 'src/Lair.c' ) }, planned_test( 'test/test_Lair.c' )] )
    allow(unity).to receive(:generate)
    expect(loginator).to receive(:log).with( /`test\/test_Lair.c`.*`#ifdef TEST`.*:defines/m, Verbosity::COMPLAIN, LogLabels::WARNING ).once

    plugin.create( request( 'Lair' ) )
  end

  it 'names the #if guard in the warning when :test_guard is #if' do
    config[:module_generator_test_guard] = :if
    resolved_defines['test/test_Lair.c'] = []
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:files_to_operate_on).and_return( [planned_test( 'test/test_Lair.c' )] )
    allow(unity).to receive(:generate)
    expect(loginator).to receive(:log).with( /`#if TEST`/, Verbosity::COMPLAIN, LogLabels::WARNING )

    plugin.create( request( 'Lair' ) )
  end

  it 'says nothing about the test define when it reaches the generated test file' do
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:files_to_operate_on).and_return( [planned_test( 'test/test_Lair.c' )] )
    allow(unity).to receive(:generate)
    expect(loginator).not_to receive(:log)

    plugin.create( request( 'Lair' ) )
  end

  it 'warns about each existing file that shares a name with a file it creates, then creates them' do
    config.merge!( collection_all_source: ['lib/Lair.c'], collection_all_headers: [], collection_all_tests: [] )
    allow(ModuleGeneratorUnity).to receive(:new).and_return( unity )
    allow(unity).to receive(:files_to_operate_on).with( 'Lair' ).and_return( [{ path: Pathname.new( 'src/Lair.c' ) }] )
    expect(loginator).to receive(:log).with( /`src\/Lair.c`.*`lib\/Lair.c`/, Verbosity::COMPLAIN, LogLabels::WARNING )
    expect(unity).to receive(:generate).with( 'Lair' )

    plugin.create( request( 'Lair' ) )
  end

  describe '#test' do
    let(:parser) { double( 'cmock_header_parser' ) }

    before(:each) do
        allow(CMockConfig).to receive(:new).and_return( double( 'cmock_config' ) )
      allow(CMockHeaderParser).to receive(:new).and_return( parser )
      allow(file_wrapper).to receive(:read).with( 'inc/widget.h' ).and_return( 'void shorty(void);' )
      allow(parser).to receive(:parse).with( 'widget', 'void shorty(void);' ).and_return( functions: [{ name: 'shorty' }] )
      allow(file_wrapper).to receive(:mkdir)
    end

    it 'writes a test file with a test for each function the header declares' do
      allow(file_wrapper).to receive(:exist?).with( 'test/test_widget.c' ).and_return( false )
      expect(file_wrapper).to receive(:write).with( 'test/test_widget.c', /void test_shorty_NeedToImplement/ )

      plugin.test( request( 'widget' ) )
    end

    it 'adds tests to an existing test file only for untested functions' do
      allow(file_wrapper).to receive(:exist?).with( 'test/test_widget.c' ).and_return( true )
      allow(file_wrapper).to receive(:read).with( 'test/test_widget.c' ).and_return( "void test_shorty(void) {}\n" )
      expect(file_wrapper).not_to receive(:write)

      plugin.test( request( 'widget' ) )
    end

    it 'warns when its test define does not reach the test file it writes' do
      resolved_defines['test/test_widget.c'] = []
      allow(file_wrapper).to receive(:exist?).with( 'test/test_widget.c' ).and_return( false )
      allow(file_wrapper).to receive(:write)
      expect(loginator).to receive(:log).with( /`test\/test_widget.c`.*`#ifdef TEST`/m, Verbosity::COMPLAIN, LogLabels::WARNING )

      plugin.test( request( 'widget' ) )
    end

    it 'refuses a header that does not exist' do
      allow(file_wrapper).to receive(:read).with( 'inc/widget.h' ).and_raise( Errno::ENOENT )

      expect { plugin.test( request( 'widget' ) ) }.to raise_error( CeedlingException, %r{`inc/widget.h`} )
    end
  end

  it 'stubs a header through CMock with the skeleton beside the source' do
    expect(CMock).to receive(:new).with( hash_including( mock_prefix: 'mock_', skeleton_path: 'src' ) ).and_return( cmock )
    expect(cmock).to receive(:setup_skeletons).with( 'inc/stubby.h' )

    plugin.stub( request( 'stubby' ) )
  end

end
