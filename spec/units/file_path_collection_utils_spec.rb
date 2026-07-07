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
