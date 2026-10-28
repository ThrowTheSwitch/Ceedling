# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/file_wrapper'
require 'ceedling/file_path_collection_utils'
require 'ceedling/filename_extension'
require 'ceedling/library_resolver'
require 'ceedling/defaults'

# GH #1368: a link tracked its libraries only by their -l and -L arguments, so a library
# rebuilt under the same name relinked nothing. The resolver finds the files they name.
describe LibraryResolver do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir( dir ) { example.run }
    end
  end

  before(:each) do
    stub_const( 'EXTENSION_LIBRARIES', FilenameExtension.new( ['.a', '.so'] ) )

    file_wrapper = FileWrapper.new( {:loginator => double('loginator').as_null_object, :verbosinator => double('verbosinator').as_null_object} )
    @resolver = described_class.new( {
      :file_wrapper               => file_wrapper,
      :file_path_collection_utils => FilePathCollectionUtils.new( {:file_wrapper => file_wrapper} )
    } )
  end

  def make(*files)
    files.each { |file| FileUtils.mkdir_p( File.dirname( file ) ); File.write( file, '' ) }
  end

  def resolve(entries, search_paths: ['vendor/lib'], files: [])
    @resolver.resolve( entries: entries, search_paths: search_paths, files: files )
  end

  it 'finds a bare name as a static or a shared library on the search paths' do
    make( 'vendor/lib/libx.a', 'vendor/lib/liby.so' )

    expect( resolve( ['x', 'y'] ) ).to eq( ['vendor/lib/libx.a', 'vendor/lib/liby.so'] )
  end

  it 'finds a bare name with the extensions toolchains add, and without the lib prefix' do
    make( 'vendor/lib/libmac.dylib', 'vendor/lib/libmingw.dll.a', 'vendor/lib/msvc.lib' )

    expect( resolve( ['mac', 'mingw', 'msvc'] ) ).to eq( ['vendor/lib/libmac.dylib', 'vendor/lib/libmingw.dll.a', 'vendor/lib/msvc.lib'] )
  end

  it 'finds the exact filename an `-l:` entry names' do
    make( 'vendor/lib/libexact.so.1' )

    expect( resolve( [':libexact.so.1'] ) ).to eq( ['vendor/lib/libexact.so.1'] )
  end

  it 'finds a path as given, or on the search paths' do
    make( 'prebuilt/libp.a', 'vendor/lib/sub/libq.a' )

    expect( resolve( ['prebuilt/libp.a', 'sub/libq.a'] ) ).to eq( ['prebuilt/libp.a', 'vendor/lib/sub/libq.a'] )
  end

  it 'finds an absolute path as given' do
    make( 'abs/libz.a' )
    absolute = File.expand_path( 'abs/libz.a' )

    expect( resolve( [absolute] ) ).to eq( ['abs/libz.a'] )
  end

  it 'finds a name in every search path that holds it, since which one links is the toolchain\'s choice' do
    make( 'one/libdup.a', 'two/libdup.a' )

    expect( resolve( ['dup'], search_paths: ['one', 'two'] ) ).to eq( ['one/libdup.a', 'two/libdup.a'] )
  end

  it 'expands decorated and globbed search paths' do
    make( 'deps/a/liba.a', 'deps/b/libb.a', 'deps/skip/libs.a' )

    expect( resolve( ['a', 'b', 's'], search_paths: ['+:deps/**', '-:deps/skip'] ) ).to eq( ['deps/a/liba.a', 'deps/b/libb.a'] )
  end

  it 'finds nothing for a library only the toolchain\'s own search paths hold, so it never reads as changed' do
    expect( resolve( ['m', 'missing.a', ':libnone.so'] ) ).to eq( [] )
  end

  it 'adds the existing files given directly, once each' do
    make( 'vendor/lib/libx.a', 'build/deps/libfusion.so.1' )

    expect( resolve( ['x'], files: ['build/deps/libfusion.so.1', 'build/deps/absent.a', 'vendor/lib/libx.a'] ) ).to eq(
      ['vendor/lib/libx.a', 'build/deps/libfusion.so.1']
    )
  end

  describe '#link_files' do
    it 'resolves entries on the configured library paths, with the files plugins publish' do
      make( 'vendor/lib/libx.a', 'build/deps/libfusion.so.1' )
      stub_const( 'PATHS_LIBRARIES', ['vendor/lib'] )
      stub_const( 'LIBRARIES_LINK_FILES', ['build/deps/libfusion.so.1'] )

      expect( @resolver.link_files( ['x', 'm'] ) ).to eq( ['vendor/lib/libx.a', 'build/deps/libfusion.so.1'] )
    end

    it 'resolves nothing when neither library paths nor plugin files are configured' do
      hide_const( 'PATHS_LIBRARIES' )
      hide_const( 'LIBRARIES_LINK_FILES' )

      expect( @resolver.link_files( ['x'] ) ).to eq( [] )
    end
  end

  # The path handling audit around GH #1370: a library search path is configured like any
  # other, with decorators and globs, and the linker reads neither
  describe '#search_path_arguments' do
    it 'gives the linker the directories a decorated, globbed library path names' do
      FileUtils.mkdir_p( ['vendor/a', 'vendor/skip'] )
      stub_const( 'PATHS_LIBRARIES', ['+:vendor/**', '-:vendor/skip'] )
      stub_const( 'LIBRARIES_PATH_FLAG', '-L${1}' )

      expect( @resolver.search_path_arguments ).to eq( ['-Lvendor', '-Lvendor/a'] )
    end

    # Quoted like every other default path argument, so a path with a space survives the shell
    it 'quotes each directory under the default flag template' do
      FileUtils.mkdir_p( 'vendor/third party/lib' )
      stub_const( 'PATHS_LIBRARIES', ['vendor/third party/lib'] )
      stub_const( 'LIBRARIES_PATH_FLAG', DEFAULT_CEEDLING_PROJECT_CONFIG[:libraries][:path_flag] )

      expect( @resolver.search_path_arguments ).to eq( ['-L "vendor/third party/lib"'] )
    end

    # A plugin's library directories join :paths ↳ :libraries once configuration is done
    it 'includes the directories a plugin adds to the library paths' do
      FileUtils.mkdir_p( ['vendor/lib', 'build/deps'] )
      stub_const( 'PATHS_LIBRARIES', ['vendor/lib'] )
      stub_const( 'LIBRARIES_PATH_FLAG', '-L${1}' )
      PATHS_LIBRARIES << 'build/deps'

      expect( @resolver.search_path_arguments ).to eq( ['-Lvendor/lib', '-Lbuild/deps'] )
    end

    it 'gives no arguments without library paths' do
      hide_const( 'PATHS_LIBRARIES' )

      expect( @resolver.search_path_arguments ).to eq( [] )
    end
  end

  it 'finds nothing without entries or search paths' do
    expect( resolve( [], search_paths: [] ) ).to eq( [] )
    expect( resolve( nil, search_paths: nil ) ).to eq( [] )
  end
end
