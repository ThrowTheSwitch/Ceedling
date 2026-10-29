# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake'  # for FileList
require 'spec_helper'
require 'ceedling/file_path_collection_utils'

describe FilePathCollectionUtils do

  # Setup: inject a mocked file_wrapper so all tests remain in memory.
  # The constructor calls setup(), which captures Dir.pwd() as @working_dir_path.
  # Tests stub directory_listing to return File.expand_path(relative_path) — absolute
  # paths rooted at the same Dir.pwd() — so shortest_path_from_working naturally
  # converts them back to the expected relative form without any filesystem access.
  before(:each) do
    @file_wrapper = double('file_wrapper')
    # #104 -- real (not stubbed-away) behavior: builds a FileList via `<<`, never
    # `.new`/`.include`, so a literal `[`/`]` survivor in an already-concrete path
    # is never mistaken for glob syntax and silently dropped. revise_filelist's own
    # final FileList construction goes through this.
    allow(@file_wrapper).to receive(:instantiate_file_list_literal) do |files|
      list = Rake::FileList.new
      files.each { |file| list << file }
      list
    end
    @fpcu = described_class.new({ file_wrapper: @file_wrapper })
  end


  describe '#collect_paths' do

    # Nil input (e.g. an unconfigured config section) must not crash
    it 'returns [] for nil input' do
      expect( @fpcu.collect_paths( nil ) ).to eq( [] )
    end

    # An empty array produces no work and no results
    it 'returns [] for an empty array' do
      expect( @fpcu.collect_paths( [] ) ).to eq( [] )
    end

    # A simple non-glob path: directory_listing returns one absolute dir entry.
    # The returned path is the relative form of that absolute entry.
    it 'returns the relative form of a simple directory path' do
      abs_src = File.expand_path( 'src' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src' ).and_return( [abs_src] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_src ).and_return( true )

      result = @fpcu.collect_paths( ['src'] )

      expect( result ).to include( 'src' )
    end

    # directory_listing returns an entry for which directory? is false (a file, not a dir).
    # Files must be silently excluded from the path collection result.
    it 'excludes non-directory entries from results' do
      abs_file = File.expand_path( 'src/foo.c' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src' ).and_return( [abs_file] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_file ).and_return( false )

      result = @fpcu.collect_paths( ['src'] )

      expect( result ).to be_empty
    end

    # A +:  decorated path must be treated identically to a bare path (additive is the default).
    # The decorator is stripped before directory_listing is called, and the dir is included.
    it 'includes a directory for a +: decorated path' do
      abs_src = File.expand_path( 'src' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src' ).and_return( [abs_src] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_src ).and_return( true )

      result = @fpcu.collect_paths( ['+:src'] )

      expect( result ).to include( 'src' )
    end

    # A -:  decorated path routes its resolved dirs to the minus set.
    # With no additive paths, the excluded dir must not appear in the result.
    it 'excludes a directory for a -: decorated path' do
      abs_src = File.expand_path( 'src' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src' ).and_return( [abs_src] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_src ).and_return( true )

      result = @fpcu.collect_paths( ['-:src'] )

      expect( result ).to be_empty
    end

    # Two input entries: one plain (additive), one with -:  (exclusion).
    # Set subtraction must keep the included path and remove the excluded one.
    it 'applies + and - sets: included path survives, excluded path is removed' do
      abs_src = File.expand_path( 'src' )
      abs_lib = File.expand_path( 'lib' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src' ).and_return( [abs_src] )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'lib' ).and_return( [abs_lib] )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      result = @fpcu.collect_paths( ['src', '-:lib'] )

      expect( result ).to include( 'src' )
      expect( result ).not_to include( 'lib' )
    end

    # A /** glob is reformed to /**/** by reform_subdirectory_glob before the listing call.
    # All dirs returned by directory_listing for the reformed glob must be in the result.
    it 'collects multiple directories from a /** glob' do
      abs_a = File.expand_path( 'src/a' )
      abs_b = File.expand_path( 'src/b' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/**/**' ).and_return( [abs_a, abs_b] )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      result = @fpcu.collect_paths( ['src/**'] )

      expect( result ).to include( 'src/a' )
      expect( result ).to include( 'src/b' )
    end

    # A /** glob triggers parent directory collection (Ceedling convention differs from Ruby glob).
    # For each matched subdir, the parent (one level up via ..) must also appear in the result.
    it 'includes parent directories for a /** glob' do
      abs_sub = File.expand_path( 'src/platform' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/**/**' ).and_return( [abs_sub] )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      result = @fpcu.collect_paths( ['src/**'] )

      expect( result ).to include( 'src' )           # parent
      expect( result ).to include( 'src/platform' )  # matched subdir
    end

    # A /** glob where directory_listing returns no subdirectories.
    # The fallback adds the base directory via no_decorators(_path) so the parent still exists.
    it 'falls back to the base directory when /** glob matches no subdirectories' do
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/**/**' ).and_return( [] )

      result = @fpcu.collect_paths( ['src/**'] )

      expect( result ).to include( 'src' )
    end


    # GH #1370 audit (G13): an exclusion dropped only the directory it named, keeping those below
    it 'excludes every directory below a `-:` exclusion' do
      kept, dropped, deep = File.expand_path( 'src/a' ), File.expand_path( 'src/exp' ), File.expand_path( 'src/exp/deep' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/**/**' ).and_return( [kept, dropped, deep] )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/exp' ).and_return( [dropped] )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      expect( @fpcu.collect_paths( ['+:src/**', '-:src/exp'] ) ).to match_array( ['src', 'src/a'] )
    end

    # GH #1370 audit (G15): a root above the build root collected the build tree
    it 'excludes every directory below an excluded path' do
      src, build = File.expand_path( 'src' ), File.expand_path( 'build/test/mocks' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( './**/**' ).and_return( [src, build] )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      expect( @fpcu.collect_paths( ['./**'], exclude: ['build'] ) ).to_not include( 'build/test/mocks' )
    end
  end


  # GH #1370 audit: the places build files mirror below, each spelled canonically
  describe '#collect_mirror_roots' do
    it 'roots a recursive entry at its base, and a plain entry at itself' do
      expect( @fpcu.collect_mirror_roots( ['src/**', 'include', './lib/*'] ) ).to eq( ['src', 'include', 'lib'] )
    end

    it 'roots a glob within an entry at each directory it names' do
      named = [File.expand_path( 'components/a/include' ), File.expand_path( 'components/b/include' )]
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'components/*/include' ).and_return( named )
      allow( @file_wrapper ).to receive( :directory? ).and_return( true )

      expect( @fpcu.collect_mirror_roots( ['components/*/include'] ) ).to eq( ['components/a/include', 'components/b/include'] )
    end

    it 'roots nothing at a `-:` exclusion, and keeps a literal bracket as part of a name' do
      expect( @fpcu.collect_mirror_roots( ['+:src/**', '-:src/exp', 'src/[legacy]'] ) ).to eq( ['src', 'src/[legacy]'] )
    end

    it 'returns [] for nil input' do
      expect( @fpcu.collect_mirror_roots( nil ) ).to eq( [] )
    end
  end


  describe '#revise_filelist' do

    # Nil list must not crash; return an empty FileList
    it 'returns an empty FileList for a nil list' do
      result = @fpcu.revise_filelist( nil, [] )

      expect( result ).to be_a( FileList )
      expect( result ).to be_empty
    end

    # Nil revisions leaves the base list entries in the result unchanged
    it 'returns the base list unchanged when revisions is nil' do
      abs_file = File.expand_path( 'src/foo.c' )

      result = @fpcu.revise_filelist( [abs_file], nil )

      expect( result ).to be_a( FileList )
      expect( result ).to include( 'src/foo.c' )
    end

    # Both inputs empty: nothing to add or subtract; result is empty
    it 'returns an empty FileList for empty list and revisions' do
      result = @fpcu.revise_filelist( [], [] )

      expect( result ).to be_a( FileList )
      expect( result ).to be_empty
    end

    # Base list entries (plain file paths, no decorators) flow through expand_path
    # and shortest_path_from_working; they must appear as relative paths in the result.
    it 'includes base list entries in the result FileList' do
      abs_file = File.expand_path( 'src/foo.c' )

      result = @fpcu.revise_filelist( [abs_file], [] )

      expect( result ).to include( 'src/foo.c' )
    end

    # A +:  revision expands via directory_listing; matching non-directory entries are added.
    # The new file must appear in the returned FileList.
    it 'adds files from a +: revision to the FileList' do
      abs_bar = File.expand_path( 'src/bar.c' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/bar.c' ).and_return( [abs_bar] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_bar ).and_return( false )

      result = @fpcu.revise_filelist( [], ['+:src/bar.c'] )

      expect( result ).to include( 'src/bar.c' )
    end

    # A -:  revision removes matching entries from the base list via set subtraction.
    # After removal the entry must not appear in the returned FileList.
    it 'removes files matching a -: revision from the FileList' do
      abs_foo = File.expand_path( 'src/foo.c' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/foo.c' ).and_return( [abs_foo] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_foo ).and_return( false )

      result = @fpcu.revise_filelist( [abs_foo], ['-:src/foo.c'] )

      expect( result ).to be_empty
    end

    # directory_listing returns a directory entry for a revision; directory? is true.
    # Directories must be excluded — only files flow into the revised FileList.
    it 'excludes directories from revision entries' do
      abs_dir = File.expand_path( 'src/subdir' )
      allow( @file_wrapper ).to receive( :directory_listing ).with( 'src/subdir' ).and_return( [abs_dir] )
      allow( @file_wrapper ).to receive( :directory? ).with( abs_dir ).and_return( true )

      result = @fpcu.revise_filelist( [], ['+:src/subdir'] )

      expect( result ).to be_empty
    end

    # Return type contract: revise_filelist always returns a FileList, never a plain array
    it 'always returns a FileList instance' do
      result = @fpcu.revise_filelist( [], [] )
      expect( result ).to be_a( FileList )
    end

  end

end

# The path handling audit around GH #1370: one place collected under two spellings is still
# one place, so an exclusion names it however it was reached
describe FilePathCollectionUtils, 'on disk' do
  require 'tmpdir'
  require 'fileutils'
  require 'ceedling/file_wrapper'

  POSIX_ONLY_COLLECTION = { unless: Gem.win_platform? }.freeze

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'app/src/a' ) )
      FileUtils.mkdir_p( File.join( @ws, 'vendor/ext' ) )
      File.write( File.join( @ws, 'vendor/ext/foo.c' ), '' )
      File.write( File.join( @ws, 'app/src/a/bar.c' ), '' )
      Dir.chdir( File.join( @ws, 'app' ) ) { example.run }
    end
  end

  before(:each) do
    file_wrapper = FileWrapper.new( { loginator: double( 'loginator' ).as_null_object, verbosinator: double( 'verbosinator' ).as_null_object } )
    @fpcu = described_class.new( { file_wrapper: file_wrapper } )
  end

  def link_ext
    File.symlink( File.join( @ws, 'vendor/ext' ), File.join( @ws, 'app/src/ext' ) )
  end

  it 'leaves out a symlinked directory below a root its `-:` entry names', **POSIX_ONLY_COLLECTION do
    link_ext

    expect(@fpcu.collect_paths( ['+:src/**', '-:src/ext'] )).to eq( ['src', 'src/a'] )
  end

  it 'collects a symlinked directory once, however many entries reach it', **POSIX_ONLY_COLLECTION do
    link_ext

    expect(@fpcu.collect_paths( ['+:src/**', '+:src/ext'] ).count { |dir| dir.end_with?( 'ext' ) }).to eq( 1 )
  end

  # An #include or a test name spells a place below a root through the root as listed,
  # as the compiler and the command line do
  it 'spells a symlinked directory below an entry\'s base as it is listed', **POSIX_ONLY_COLLECTION do
    link_ext

    expect(@fpcu.collect_paths( ['+:src/**'] )).to include( 'src/ext' )
    expect(@fpcu.revise_filelist( ['src/ext/foo.c'], ['+:src/a/*.c'] ).to_a).to eq( ['src/ext/foo.c', 'src/a/bar.c'] )
  end

  it 'spells an entry\'s symlinked base as it really is', **POSIX_ONLY_COLLECTION do
    File.symlink( File.join( @ws, 'vendor' ), File.join( @ws, 'app/vend' ) )

    expect(@fpcu.collect_paths( ['+:vend/**'] )).to eq( ['../vendor', '../vendor/ext'] )
  end

  it 'removes a file below a symlinked directory that a `-:` revision names', **POSIX_ONLY_COLLECTION do
    link_ext

    expect(@fpcu.revise_filelist( ['src/a/bar.c', 'src/ext/foo.c'], ['-:src/ext/foo.c'] ).to_a).to eq( ['src/a/bar.c'] )
    expect(@fpcu.revise_filelist( ['src/ext/foo.c'], ['+:src/ext/foo.c'] ).to_a.size).to eq( 1 )
  end

  # macOS spells /tmp as /private/tmp, and a build root may be written through any symlink
  it 'excludes a build root written through a symlink', **POSIX_ONLY_COLLECTION do
    FileUtils.mkdir_p( 'build/test' )
    File.symlink( File.join( @ws, 'app' ), File.join( @ws, 'link' ) )

    expect(@fpcu.collect_paths( ['+:./**'], exclude: [File.join( @ws, 'link/build' )] )).to eq( ['.', 'src', 'src/a'] )
  end

  it 'keeps a directory an additive entry names below a `-:` entry, and leaves out one both name' do
    FileUtils.mkdir_p( ['src/legacy/keep', 'src/legacy/other'] )

    expect(@fpcu.collect_paths( ['+:src/**', '-:src/legacy', '+:src/legacy/keep'] )).to eq( ['src', 'src/a', 'src/legacy/keep'] )
    expect(@fpcu.collect_paths( ['+:src/**', '+:src/legacy', '-:src/legacy'] )).to eq( ['src', 'src/a'] )
  end

  it 'leaves out the files a revision glob matches below an excluded root, but keeps one it names exactly' do
    FileUtils.mkdir_p( ['build/gen', 'build/test/mocks'] )
    File.write( 'build/gen/table.c', '' )
    File.write( 'build/test/mocks/mock_x.c', '' )

    expect(@fpcu.revise_filelist( ['src/a/bar.c'], ['+:**/*.c'], exclude: ['build'] ).to_a).to eq( ['src/a/bar.c'] )
    expect(@fpcu.revise_filelist( [], ['+:build/gen/table.c'], exclude: ['build'] ).to_a).to eq( ['build/gen/table.c'] )
  end

  # Only the entries that name a directory decide whether it is kept
  it 'judges each directory by the entries that name it, not every entry\'s base' do
    FileUtils.mkdir_p( ['src/legacy/x/inc', 'src/legacy/keep/sub'] )

    expect(@fpcu.collect_paths( ['+:src/**', '+:src/legacy/*/inc', '-:src'] )).to eq( ['src/legacy/x/inc'] )
    expect(@fpcu.collect_paths( ['+:src/**', '+:src/legacy/keep', '-:src/legacy'] )).to contain_exactly( 'src', 'src/a', 'src/legacy/keep' )
  end

  it 'leaves out many directories below a `-:` entry quickly' do
    200.times { |index| FileUtils.mkdir_p( "vendor_tree/d#{index}/x" ) }
    200.times { |index| FileUtils.mkdir_p( "src/m#{index}" ) }

    started = Process.clock_gettime( Process::CLOCK_MONOTONIC )
    result  = @fpcu.collect_paths( ['+:./**', '-:vendor_tree/**'] )

    expect(result).to_not include( 'vendor_tree' )
    expect(Process.clock_gettime( Process::CLOCK_MONOTONIC ) - started).to be < 2.0
  end

  describe '#collect_mirror_roots' do
    it 'reads a literal bracket in an entry with a glob as part of a name (#104)' do
      FileUtils.mkdir_p( 'lib[v2]/x/inc' )

      expect(@fpcu.collect_mirror_roots( ['lib[v2]/*/inc'] )).to eq( ['lib[v2]/x/inc'] )
    end

    it 'roots a doubled recursive glob at its base' do
      expect(@fpcu.collect_mirror_roots( ['src/**/**'] )).to eq( ['src'] )
    end
  end
end
