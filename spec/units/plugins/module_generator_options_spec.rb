# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/module_generator/lib', __dir__ ) )

require 'module_generator_request'
require 'module_generator_options'

describe ModuleGeneratorOptions do

  let(:config) do
    {
      collection_paths_source:  ['src', 'src/lab'],
      collection_paths_include: ['inc', 'inc/lab'],
      collection_paths_test:    ['test', 'test/lab'],
      project_test_file_prefix: 'test_',
      cmock_mock_prefix:        'mock_',
      module_generator_boilerplates: { src: '/* src */', inc: '', tst: '' }
    }
  end

  let(:cmock_config) { { mock_prefix: 'mock_', treat_as: { 'BYTE' => 'HEX8' }, includes: ['extra.h'] } }

  # Matches a hint to the path whose last segment it names, the way the real matcher
  # ranks an exact trailing match first
  let(:path_finder) { ->( hint, paths ) { paths.find { |path| path.end_with?( "/#{hint}" ) } } }

  let(:files) { {} }

  def options(**overrides)
    return described_class.new(
      config:             config.merge( overrides ),
      cmock_config:       cmock_config,
      path_finder:        path_finder,
      boilerplate_reader: ->( path ) { files[path] }
    )
  end

  def request(name, path_hint: nil, pattern: nil)
    return ModuleGeneratorRequest.new( name: name, path_hint: path_hint, pattern: pattern )
  end

  describe '#unity' do
    it 'carries the project prefixes, the pattern, and the module generator defaults' do
      expect(options.unity( request( 'Lair', pattern: 'mch' ) )).to include(
        pattern: 'mch', test_prefix: 'test_', mock_prefix: 'mock_', test_define: 'TEST', update_svn: false, naming: nil,
        includes: { src: [], inc: [], tst: [] }
      )
    end

    it 'guards tests with #ifdef unless :test_guard asks for #if' do
      expect(options.unity( request( 'x' ) )[:test_guard]).to eq( 'ifdef' )
      expect(options( module_generator_test_guard: :if ).unity( request( 'x' ) )[:test_guard]).to eq( 'if' )
    end

    it 'refuses an unknown :test_guard' do
      expect { options( module_generator_test_guard: :ifndef ) }.to raise_error( CeedlingException, /:test_guard.*ifndef/ )
    end

    it 'never asks Unity to run Subversion, even when :update_svn is configured' do
      expect(options( module_generator_update_svn: true ).unity( request( 'x' ) )[:update_svn]).to be( false )
    end

    it 'uses the first path of each list without a hint' do
      expect(options.unity( request( 'Lair' ) )).to include( path_src: 'src', path_inc: 'inc', path_tst: 'test' )
    end

    it 'uses configured paths without a hint' do
      unity = options( module_generator_path_src: 'source/', module_generator_path_tst: 'tests/' ).unity( request( 'Lair' ) )

      expect(unity).to include( path_src: 'source/', path_inc: 'inc', path_tst: 'tests/' )
    end

    it 'uses the paths a hint matches' do
      expect(options.unity( request( 'Lair', path_hint: 'lab' ) )).to include( path_src: 'src/lab', path_inc: 'inc/lab', path_tst: 'test/lab' )
    end

    it 'falls back to the first path of a list the hint matches nothing in' do
      unity = options( collection_paths_test: ['test'] ).unity( request( 'Lair', path_hint: 'lab' ) )

      expect(unity).to include( path_src: 'src/lab', path_tst: 'test' )
    end

    it 'refuses a hint that matches nothing in any list' do
      expect { options.unity( request( 'Lair', path_hint: 'bad' ) ) }.to raise_error( CeedlingException, /`bad`/ )
    end

    it 'places headers with the source when no include paths are listed' do
      unity = options( collection_paths_include: [] ).unity( request( 'Lair', path_hint: 'lab' ) )

      expect(unity).to include( path_src: 'src/lab', path_inc: 'src/lab' )
    end

    it 'passes :naming through to Unity unchanged' do
      expect(options( module_generator_naming: :bumpy ).unity( request( 'x' ) )[:naming]).to eq( 'bumpy' )
      expect(options( module_generator_naming: :camel ).unity( request( 'x' ) )[:naming]).to eq( 'camel' )
      expect(options( module_generator_naming: :snake ).unity( request( 'x' ) )[:naming]).to eq( 'snake' )
      expect(options( module_generator_naming: 'caps' ).unity( request( 'x' ) )[:naming]).to eq( 'caps' )
    end

    it 'refuses an unknown :naming' do
      expect { options( module_generator_naming: :kebab ) }.to raise_error( CeedlingException, /:naming.*kebab/ )
    end

    it 'fills in includes for each kind of file' do
      unity = options( module_generator_includes: { tst: ['defs.h'] } ).unity( request( 'x' ) )

      expect(unity[:includes]).to eq( src: [], inc: [], tst: ['defs.h'] )
    end

    it 'reads boilerplate files over configured boilerplates without changing the configuration' do
      files['bp/src.txt'] = '/* from a file */'
      unity = options( module_generator_boilerplate_files: { src: 'bp/src.txt' } ).unity( request( 'x' ) )

      expect(unity[:boilerplates]).to eq( src: '/* from a file */', inc: '', tst: '' )
      expect(config[:module_generator_boilerplates][:src]).to eq( '/* src */' )
    end

    it 'refuses a boilerplate file that does not exist' do
      expect { options( module_generator_boilerplate_files: { tst: 'missing.txt' } ) }
        .to raise_error( CeedlingException, /missing\.txt/ )
    end
  end

  it 'reports its test define' do
    expect(options( module_generator_test_define: 'UNIT_TEST' ).test_define).to eq( 'UNIT_TEST' )
    expect(options.test_define).to eq( 'TEST' )
  end

  describe '#test' do
    it 'reads the header from the include path and writes the test to the test path' do
      test = options.test( request( 'widget', path_hint: 'lab' ) )

      expect(test).to include( header: 'inc/lab/widget.h', path: 'test/lab/test_widget.c' )
    end

    it 'keeps a subdirectory a slash names for both the header and the test' do
      test = options.test( request( 'rev/widget' ) )

      expect(test).to include( header: 'inc/rev/widget.h', path: 'test/rev/test_widget.c' )
      expect(test[:file]).to include( module_name: 'widget', header: 'widget.h' )
    end

    it 'describes the test file with the configured includes, boilerplate, and guard' do
      test = options(
        module_generator_includes: { tst: ['defs.h'] }, module_generator_boilerplates: { tst: '/* t */' },
        module_generator_test_define: 'UNIT_TEST', module_generator_test_guard: :if
      ).test( request( 'widget' ) )

      expect(test[:file]).to include( includes: ['defs.h'], boilerplate: '/* t */', test_define: 'UNIT_TEST', test_guard: 'if' )
    end

    it 'parses the header with the project CMock configuration' do
      expect(options.test( request( 'widget' ) )[:cmock]).to include( treat_as: { 'BYTE' => 'HEX8' } )
    end
  end

  describe '#stub' do
    it 'reads the header from the include path and writes the skeleton to the source path' do
      stub = options.stub( request( 'stubby', path_hint: 'lab' ) )

      expect(stub[:header]).to eq( 'inc/lab/stubby.h' )
      expect(stub[:cmock]).to include( skeleton_path: 'src/lab', subdir: nil )
    end

    it 'keeps a subdirectory a slash names for both the header and the skeleton' do
      stub = options.stub( request( 'rev/stubby' ) )

      expect(stub[:header]).to eq( 'inc/rev/stubby.h' )
      expect(stub[:cmock]).to include( skeleton_path: 'src', subdir: 'rev' )
    end

    it 'builds on the project CMock configuration' do
      expect(options.stub( request( 'stubby' ) )[:cmock]).to include( treat_as: { 'BYTE' => 'HEX8' }, mock_prefix: 'mock_' )
    end
  end

end
