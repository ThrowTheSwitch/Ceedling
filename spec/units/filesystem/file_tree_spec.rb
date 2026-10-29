# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'file_tree_helper'
require 'ceedling/filesystem/file_tree'
require 'ceedling/constants'
require 'ceedling/exceptions'

# GH #1376 (a follow-up to #1292): on a Windows share with Data Deduplication, `File.lstat`
# reports deduplicated files as directories while `File.stat` reports them correctly. A
# copy that classifies by `lstat` makes a directory where the file belongs, and every later
# copy trips over it. FileTree must never depend on `lstat`, and must heal what it finds.
describe FileTree, filesystem: true do
  include FileTreeHelper

  around(:each) do |example|
    with_tree_root do |root|
      @root = root
      @src  = File.join( root, 'src' )
      @dst  = File.join( root, 'dst' )
      example.run
    end
  end

  def sync(source = @src, destination = @dst, **options)
    FileTree.sync( source, destination, publish: FileTreeHelper::PUBLISH, **options )
  end

  def files_of(root)
    FileTree.each_file( root ).to_a
  end

  # Writes files named with glob metacharacters below `dir`, returning the names this
  # filesystem accepts. Windows and FAT refuse `*` and `?`.
  def written_glob_names(dir)
    return ['a[1].c', 'b{x,y}.c', 'c*.c', 'd?.c'].select do |name|
      write( File.join( dir, name ) )
      true
    rescue SystemCallError
      false
    end
  end

  # ---- the reported failure, and its absence --------------------------------------------

  describe 'under an lstat that reports a regular file as a directory' do
    before(:each) do
      write( File.join( @src, 'unity.c' ), 'int x;' )
      write( File.join( @src, 'unity.h' ), 'int y;' )
    end

    # The control: stock FileUtils.cp_r fails as reported, so the stand-in reproduces it
    it 'makes FileUtils.cp_r fail on the misreported file' do
      lie_about_lstat( %r{unity\.c\z} )

      expect { FileUtils.cp_r( "#{@src}/.", @dst ) }.to raise_error( SystemCallError, /unity\.c/ )
    end

    it 'leaves .sync copying every file as a file' do
      lie_about_lstat( // )

      result = sync

      expect( result.copied ).to eq( 2 )
      expect( File.file?( File.join( @dst, 'unity.c' ) ) ).to be( true )
      expect( File.read( File.join( @dst, 'unity.c' ) ) ).to eq( 'int x;' )
    end

    it 'leaves .each_file listing every file' do
      lie_about_lstat( // )

      expect( files_of( @src ).map( &:first ) ).to eq( ['unity.c', 'unity.h'] )
    end
  end

  # The guard: correctness never rests on lstat, healing included
  it 'never calls File.lstat while walking, copying, and healing an empty stray directory' do
    write( File.join( @src, 'a/b/c.c' ), 'c' )
    FileUtils.mkdir_p( File.join( @dst, 'a/b/c.c' ) )
    forbid_lstat

    sync

    expect( File.file?( File.join( @dst, 'a/b/c.c' ) ) ).to be( true )
  end

  # ---- walking ---------------------------------------------------------------------------

  describe '.each_file' do
    it 'yields each regular file by its relative path and its source path, sorted, dotfiles included' do
      write( File.join( @src, 'top.c' ) )
      write( File.join( @src, 'sub/deep/inner.h' ) )
      write( File.join( @src, '.hidden' ) )
      FileUtils.mkdir_p( File.join( @src, 'empty' ) )

      expect( files_of( @src ) ).to eq( [
        ['.hidden',          File.join( @src, '.hidden' )],
        ['sub/deep/inner.h', File.join( @src, 'sub/deep/inner.h' )],
        ['top.c',            File.join( @src, 'top.c' )]
      ] )
    end

    it 'lists names holding glob metacharacters literally' do
      names = written_glob_names( File.join( @src, 'dir[1]' ) )

      expect( files_of( @src ).map( &:first ) ).to eq( names.map { |name| "dir[1]/#{name}" }.sort )
    end

    it 'raises when the root is not a directory' do
      expect { files_of( File.join( @root, 'nope' ) ) }.to raise_error( CeedlingException, /nope/ )
    end

    it 'neither lists nor enters an entry `skip` names' do
      write( File.join( @src, 'keep.c' ) )
      write( File.join( @src, '.hidden/x.c' ) )
      symlink_or_skip( File.join( @root, 'nowhere' ), File.join( @src, '.hidden/dangling.c' ) )

      listed = FileTree.each_file( @src, skip: ->( name ) { name.start_with?( '.' ) } ).to_a.map( &:first )

      expect( listed ).to eq( ['keep.c'] )
    end

    it 'names a directory it cannot list' do
      FileUtils.mkdir_p( File.join( @src, 'locked' ) )
      allow(Dir).to receive(:children).and_call_original
      allow(Dir).to receive(:children).with( File.join( @src, 'locked' ) ).and_raise( Errno::EACCES )

      expect { files_of( @src ) }.to raise_error( CeedlingException, /locked.*could not be listed/ )
    end

    it 'names an entry it cannot read' do
      write( File.join( @src, 'locked.c' ) )
      allow(File).to receive(:stat).and_call_original
      allow(File).to receive(:stat).with( File.join( @src, 'locked.c' ) ).and_raise( Errno::EACCES )

      expect { files_of( @src ) }.to raise_error( CeedlingException, /locked\.c.*could not be read/ )
    end

    # Loop detection is a safeguard, and must not stop a walk it cannot apply to
    it 'walks a directory whose real path cannot be resolved' do
      write( File.join( @src, 'sub/u.c' ) )
      allow(File).to receive(:realpath).and_call_original
      allow(File).to receive(:realpath).with( File.join( @src, 'sub' ) ).and_raise( Errno::EACCES )

      expect( files_of( @src ).map( &:first ) ).to eq( ['sub/u.c'] )
    end
  end

  # ---- copying ---------------------------------------------------------------------------

  describe '.sync' do
    it 'copies a nested tree, dotfiles and empty directories included' do
      write( File.join( @src, 'top.c' ) )
      write( File.join( @src, 'sub/deep/inner.h' ), 'inner' )
      write( File.join( @src, '.hidden' ) )
      FileUtils.mkdir_p( File.join( @src, 'empty' ) )

      sync

      expect( tree_of( @dst ) ).to eq( tree_of( @src ) )
      expect( File.read( File.join( @dst, 'sub/deep/inner.h' ) ) ).to eq( 'inner' )
    end

    it 'copies names holding glob metacharacters' do
      names = written_glob_names( File.join( @src, 'dir[1]' ) )

      sync

      names.each { |name| expect( File.file?( File.join( @dst, 'dir[1]', name ) ) ).to be( true ), name }
    end

    it 'writes nothing when every file already matches, keeping each file\'s modification time' do
      write( File.join( @src, 'u.c' ), 'same' )
      sync
      old = Time.at( 1_000_000_000 )
      File.utime( old, old, File.join( @dst, 'u.c' ) )

      result = sync

      expect( [result.copied, result.unchanged] ).to eq( [0, 1] )
      expect( File.mtime( File.join( @dst, 'u.c' ) ).to_i ).to eq( old.to_i )
    end

    it 'replaces a file whose contents differ, even at the same size' do
      write( File.join( @src, 'u.c' ), 'v1' )
      sync
      write( File.join( @src, 'u.c' ), 'v2' )

      expect( sync.copied ).to eq( 1 )
      expect( File.read( File.join( @dst, 'u.c' ) ) ).to eq( 'v2' )
    end

    it 'leaves files the source lacks' do
      write( File.join( @src, 'u.c' ) )
      write( File.join( @dst, 'extra.c' ) )

      sync

      expect( File.file?( File.join( @dst, 'extra.c' ) ) ).to be( true )
    end

    it 'raises when the source is not a directory' do
      expect { sync( File.join( @root, 'nope' ) ) }.to raise_error( CeedlingException, /nope/ )
    end
  end

  # ---- healing ---------------------------------------------------------------------------

  describe '.sync healing' do
    it 'replaces an empty directory where a file belongs, and says so' do
      write( File.join( @src, 'unity.h' ), 'int x;' )
      FileUtils.mkdir_p( File.join( @dst, 'unity.h' ) )
      logged = []

      result = sync( log: ->( *entry ) { logged << entry } )

      expect( result.healed ).to eq( 1 )
      expect( File.read( File.join( @dst, 'unity.h' ) ) ).to eq( 'int x;' )
      expect( logged ).to include( ["Replaced a directory where the file '#{File.join( @dst, 'unity.h' )}' belongs", Verbosity::COMPLAIN, LogLabels::NOTICE] )
    end

    it 'replaces a directory with contents where a file belongs' do
      write( File.join( @src, 'unity.c' ), 'int x;' )
      write( File.join( @dst, 'unity.c', 'junk.txt' ) )

      sync

      expect( File.read( File.join( @dst, 'unity.c' ) ) ).to eq( 'int x;' )
    end

    it 'replaces a file where a directory belongs, and says so' do
      write( File.join( @src, 'sub/u.c' ), 'int x;' )
      write( File.join( @dst, 'sub' ), 'i am a file' )
      logged = []

      result = sync( log: ->( *entry ) { logged << entry } )

      expect( result.healed ).to eq( 1 )
      expect( File.read( File.join( @dst, 'sub/u.c' ) ) ).to eq( 'int x;' )
      expect( logged ).to include( ["Replaced a file where the directory '#{File.join( @dst, 'sub' )}' belongs", Verbosity::COMPLAIN, LogLabels::NOTICE] )
    end

    it 'replaces a file where the destination directory itself belongs' do
      write( File.join( @src, 'u.c' ), 'int x;' )
      write( @dst, 'i am a file' )

      sync

      expect( File.read( File.join( @dst, 'u.c' ) ) ).to eq( 'int x;' )
    end

    it 'replaces a dangling link where a directory belongs' do
      write( File.join( @src, 'sub/u.c' ), 'int x;' )
      FileUtils.mkdir_p( @dst )
      symlink_or_skip( File.join( @root, 'nowhere' ), File.join( @dst, 'sub' ) )

      sync

      expect( File.read( File.join( @dst, 'sub/u.c' ) ) ).to eq( 'int x;' )
    end

    # Another run can heal the same entry first, publishing its file where this run found
    # a directory. That file is never deleted, only published over, so a reader always finds
    # one.
    it 'publishes over a file another run put in place of the directory it found, without deleting it' do
      write( File.join( @src, 'unity.h' ), 'int x;' )
      FileUtils.mkdir_p( File.join( @dst, 'unity.h' ) )
      allow(Dir).to receive(:rmdir).and_wrap_original do |original, path|
        original.call( path )
        File.write( path, 'published by another run' )
        raise Errno::ENOTDIR, path
      end
      allow(FileUtils).to receive(:rm_r).and_call_original

      result = sync

      expect(FileUtils).not_to have_received(:rm_r)
      expect( [result.copied, result.healed] ).to eq( [1, 0] )
      expect( File.read( File.join( @dst, 'unity.h' ) ) ).to eq( 'int x;' )
    end

    it 'replaces a link to a directory where a file belongs, and says so' do
      write( File.join( @src, 'unity.h' ), 'int x;' )
      FileUtils.mkdir_p( File.join( @root, 'elsewhere' ) )
      FileUtils.mkdir_p( @dst )
      symlink_or_skip( File.join( @root, 'elsewhere' ), File.join( @dst, 'unity.h' ) )

      result = sync

      expect( result.healed ).to eq( 1 )
      expect( File.read( File.join( @dst, 'unity.h' ) ) ).to eq( 'int x;' )
      expect( File.directory?( File.join( @root, 'elsewhere' ) ) ).to be( true )
    end
  end

  # ---- links (each skips where links cannot be made) -------------------------------------

  describe 'links' do
    it 'copies a tree whose root is a link' do
      write( File.join( @root, 'real/u.c' ), 'int x;' )
      symlink_or_skip( File.join( @root, 'real' ), @src )

      sync

      expect( File.read( File.join( @dst, 'u.c' ) ) ).to eq( 'int x;' )
    end

    it 'copies a linked file as a regular file with its target\'s contents' do
      write( File.join( @root, 'elsewhere/real.c' ), 'int x;' )
      FileUtils.mkdir_p( @src )
      symlink_or_skip( File.join( @root, 'elsewhere/real.c' ), File.join( @src, 'link.c' ) )

      sync

      expect( File.symlink?( File.join( @dst, 'link.c' ) ) ).to be( false )
      expect( File.read( File.join( @dst, 'link.c' ) ) ).to eq( 'int x;' )
    end

    it 'descends a linked directory' do
      write( File.join( @root, 'elsewhere/inner.c' ), 'int x;' )
      FileUtils.mkdir_p( @src )
      symlink_or_skip( File.join( @root, 'elsewhere' ), File.join( @src, 'linked_dir' ) )

      expect( files_of( @src ).map( &:first ) ).to eq( ['linked_dir/inner.c'] )
    end

    # The canary: characterizes Ruby, not FileTree. A copy walking with Dir.glob('**/*')
    # silently misses a linked directory's contents. If this ever fails, Ruby changed.
    it 'is not descended by Dir.glob(\'**/*\')' do
      write( File.join( @root, 'elsewhere/inner.c' ), 'int x;' )
      FileUtils.mkdir_p( @src )
      symlink_or_skip( File.join( @root, 'elsewhere' ), File.join( @src, 'linked_dir' ) )

      found = Dir.glob( '**/*', base: @src )

      expect( found ).to include( 'linked_dir' )
      expect( found ).to_not include( 'linked_dir/inner.c' )
    end

    it 'raises on a link loop instead of recursing forever' do
      write( File.join( @src, 'a/u.c' ) )
      symlink_or_skip( @src, File.join( @src, 'a/back' ) )

      expect { files_of( @src ) }.to raise_error( CeedlingException, /loop/i )
    end

    it 'raises on a dangling link, naming it' do
      FileUtils.mkdir_p( @src )
      symlink_or_skip( File.join( @root, 'nowhere' ), File.join( @src, 'dangling.c' ) )

      expect { files_of( @src ) }.to raise_error( CeedlingException, /dangling\.c/ )
    end
  end

  # ---- retries ---------------------------------------------------------------------------

  describe '.sync retries' do
    let(:delays) { [0.01, 0.02, 0.04] }

    # A publish step that raises `error` for its first `failures` calls
    def failing_publish(failures, error)
      calls = 0
      lambda do |source, destination|
        calls += 1
        raise error, 'simulated' if calls <= failures

        FileTreeHelper::PUBLISH.call( source, destination )
      end
    end

    def sync_with(publish)
      sleeps = []
      logged = []
      write( File.join( @src, 'u.c' ), 'ok' )
      outcome = begin
        FileTree.sync( @src, @dst, publish: publish, retry_delays: delays, sleep: ->( delay ) { sleeps << delay }, log: ->( *entry ) { logged << entry } )
      rescue StandardError => e
        e
      end
      [outcome, sleeps, logged]
    end

    [Errno::EACCES, Errno::EBUSY, Errno::EPERM, Errno::EINTR].each do |error|
      it "retries #{error.name.split( '::' ).last} with each delay in turn, then succeeds" do
        outcome, sleeps, = sync_with( failing_publish( 2, error ) )

        expect( outcome.copied ).to eq( 1 )
        expect( sleeps ).to eq( delays.first( 2 ) )
        expect( File.read( File.join( @dst, 'u.c' ) ) ).to eq( 'ok' )
      end
    end

    it 'fails with a CeedlingException naming the file and the retries once every delay is spent, and logs it' do
      outcome, sleeps, logged = sync_with( failing_publish( 99, Errno::EACCES ) )

      expect( outcome ).to be_a( CeedlingException )
      expect( outcome.message ).to match( /#{Regexp.escape( File.join( @dst, 'u.c' ) )}.* after 3 retries/ )
      expect( sleeps ).to eq( delays )
      expect( logged.map { |message, verbosity, *| [message, verbosity] } ).to include( [outcome.message, Verbosity::ERRORS] )
    end

    it 'logs each retry for debugging' do
      _, _, logged = sync_with( failing_publish( 1, Errno::EBUSY ) )

      expect( logged.map { |message, verbosity, *| [message[/\ARetrying copy to/], verbosity] } ).to include( ['Retrying copy to', Verbosity::DEBUG] )
    end

    # A scanner or sync client can hold the destination too, not only the file being written
    it 'retries a destination file it cannot yet read' do
      write( File.join( @dst, 'u.c' ), 'no' )
      reads = 0
      allow(FileUtils).to receive(:compare_file).and_wrap_original do |original, *args|
        reads += 1
        raise Errno::EACCES, 'simulated' if reads == 1

        original.call( *args )
      end

      outcome, sleeps, = sync_with( FileTreeHelper::PUBLISH )

      expect( outcome.copied ).to eq( 1 )
      expect( sleeps ).to eq( delays.first( 1 ) )
    end

    it 'retries a heal that fails transiently' do
      FileUtils.mkdir_p( File.join( @dst, 'u.c' ) )
      calls = 0
      allow(Dir).to receive(:rmdir).and_wrap_original do |original, *args|
        calls += 1
        raise Errno::EACCES, 'simulated' if calls == 1

        original.call( *args )
      end

      outcome, sleeps, = sync_with( FileTreeHelper::PUBLISH )

      expect( [outcome.copied, outcome.healed] ).to eq( [1, 1] )
      expect( sleeps ).to eq( delays.first( 1 ) )
    end

    it 'retries a stray directory with contents it cannot yet remove, counting one heal' do
      write( File.join( @dst, 'u.c', 'junk' ) )
      calls = 0
      allow(FileUtils).to receive(:rm_r).and_wrap_original do |original, *args|
        calls += 1
        raise Errno::EACCES, 'simulated' if calls == 1

        original.call( *args )
      end

      outcome, sleeps, logged = sync_with( FileTreeHelper::PUBLISH )

      expect( [outcome.copied, outcome.healed] ).to eq( [1, 1] )
      expect( sleeps ).to eq( delays.first( 1 ) )
      expect( logged.count { |message, *| message.start_with?( 'Replaced a directory' ) } ).to eq( 1 )
    end

    it 'retries a file it cannot yet remove where a directory belongs' do
      write( File.join( @dst, 'sub' ), 'i am a file' )
      write( File.join( @src, 'sub', 'v.c' ), 'v' )
      calls = 0
      allow(File).to receive(:unlink).and_wrap_original do |original, *args|
        calls += 1
        raise Errno::EACCES, 'simulated' if calls == 1

        original.call( *args )
      end

      outcome, sleeps, = sync_with( FileTreeHelper::PUBLISH )

      expect( outcome.healed ).to eq( 1 )
      expect( sleeps ).to eq( delays.first( 1 ) )
      expect( File.read( File.join( @dst, 'sub', 'v.c' ) ) ).to eq( 'v' )
    end

    [Errno::ENOSPC, Errno::EISDIR, Errno::ENOTDIR].each do |error|
      it "fails at once on #{error.name.split( '::' ).last}, which retrying cannot clear" do
        outcome, sleeps, = sync_with( failing_publish( 1, error ) )

        expect( outcome ).to be_a( error )
        expect( sleeps ).to be_empty
      end
    end
  end

  # ---- a single file ---------------------------------------------------------------------

  describe '.sync_file' do
    it 'copies one file into a directory, healing and skipping as .sync does' do
      write( File.join( @src, 'ceedling.h' ), 'v1' )
      FileUtils.mkdir_p( File.join( @dst, 'ceedling.h' ) )

      first  = FileTree.sync_file( File.join( @src, 'ceedling.h' ), @dst, publish: FileTreeHelper::PUBLISH )
      second = FileTree.sync_file( File.join( @src, 'ceedling.h' ), @dst, publish: FileTreeHelper::PUBLISH )

      expect( [first.copied, first.healed, second.unchanged] ).to eq( [1, 1, 1] )
      expect( File.read( File.join( @dst, 'ceedling.h' ) ) ).to eq( 'v1' )
    end

    it 'raises when the source is not a regular file' do
      FileUtils.mkdir_p( File.join( @src, 'dir.h' ) )

      expect { FileTree.sync_file( File.join( @src, 'dir.h' ), @dst, publish: FileTreeHelper::PUBLISH ) }.to raise_error( CeedlingException, /dir\.h/ )
    end
  end
end
