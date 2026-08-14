# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'yaml'
require 'ceedling/file_wrapper'
require 'ceedling/yaml_wrapper'
require 'ceedling/dependencies/dependency_debug_tree'

describe DependencyDebugTree do

  before(:each) do
    @file_wrapper = instance_double('FileWrapper')
    # real: pure in-memory YAML (de)serialization via load_string only, no FS of its own
    @yaml_wrapper = YamlWrapper.new({ file_wrapper: double('file_wrapper').as_null_object })

    # A tiny in-memory fake file store so writes and reads round-trip within
    # a single example, without ever touching a real disk.
    @files = {}
    allow( @file_wrapper ).to receive(:mkdir)
    allow( @file_wrapper ).to receive(:dirname) { |path| File.dirname( path ) }
    allow( @file_wrapper ).to receive(:write) { |path, content| @files[path] = content }
    allow( @file_wrapper ).to receive(:read) { |path| @files.fetch( path ) { raise "unstubbed read: #{path}" } }
    # `exist?` treats `path` as existing if it's a written file OR a
    # directory containing one (mirroring a real filesystem's directory
    # semantics), since #prune checks `exist?` on a *directory*, not a file.
    allow( @file_wrapper ).to receive(:exist?) { |path| @files.key?( path ) || @files.keys.any? { |p| p.start_with?( "#{path}/" ) } }
    allow( @file_wrapper ).to receive(:rm_rf) { |path| @files.reject! { |p, _| p == path || p.start_with?( "#{path}/" ) } }

    @tree = described_class.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => @yaml_wrapper } )
  end

  describe '#write_snapshot / #read_snapshot' do
    it 'round-trips path and hash unconditionally' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc123' )

      snapshot = @tree.read_snapshot( 'debug', '/proj/foo.o' )

      expect( snapshot['path'] ).to eq('/proj/foo.o')
      expect( snapshot['hash'] ).to eq('abc123')
      expect( snapshot ).to have_key('captured_at')
    end

    it 'omits meta entirely when not given, rather than recording it as nil' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' ) ).not_to have_key('meta')
    end

    it 'records meta when given' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc', meta: { 'opt_level' => 2 } )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' )['meta'] ).to eq( 'opt_level' => 2 )
    end

    it 'omits content entirely when not given' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' ) ).not_to have_key('content')
    end

    it 'records content when given' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc', content: "int main() {}\n" )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' )['content'] ).to eq("int main() {}\n")
    end

    it 'records truncated + size, not content, for a truncated capture' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc', truncated: true, size: 99_999 )

      snapshot = @tree.read_snapshot( 'debug', '/proj/foo.o' )
      expect( snapshot['truncated'] ).to be(true)
      expect( snapshot['size'] ).to eq(99_999)
      expect( snapshot ).not_to have_key('content')
    end

    it 'returns nil for a path that was never snapshotted' do
      expect( @tree.read_snapshot( 'debug', '/proj/never-captured.o' ) ).to be_nil
    end

    it 'returns nil (rather than raising) for a corrupt snapshot file' do
      # Write directly into the fake store, bypassing #write_snapshot, to
      # simulate a hand-corrupted or partially-written snapshot.yml.
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' ) # establishes the real path via mkdir/write plumbing
      corrupt_path = @files.keys.find { |p| p.end_with?('snapshot.yml') }
      @files[corrupt_path] = '{ not: valid: yaml: ::: '

      expect { @tree.read_snapshot( 'debug', '/proj/foo.o' ) }.not_to raise_error
      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' ) ).to be_nil
    end

    it 'writes different targets to different directories, not colliding' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'foo-hash' )
      @tree.write_snapshot( 'debug', '/proj/bar.o', hash: 'bar-hash' )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' )['hash'] ).to eq('foo-hash')
      expect( @tree.read_snapshot( 'debug', '/proj/bar.o' )['hash'] ).to eq('bar-hash')
    end

    it 'mirrors an absolute path as a nested directory tree under debug_root' do
      @tree.write_snapshot( '/build/.dep_cache_debug', '/Users/dev/project/src/foo.c', hash: 'abc' )

      written_path = @files.keys.first
      expect( written_path ).to start_with('/build/.dep_cache_debug/Users/dev/project/src/foo.c/')
    end

    it 'substitutes a Windows drive letter colon so it forms a valid nested directory name' do
      @tree.write_snapshot( 'C:/build/.dep_cache_debug', 'C:\\proj\\src\\foo.c', hash: 'abc' )

      written_path = @files.keys.first
      expect( written_path ).not_to include('C:\\proj')
      expect( written_path ).to include('C/proj/src/foo.c')
    end
  end

  # #snapshot_file/#diagnosis_file are the single source of truth for where
  # a path's debug files live -- public specifically so callers (including
  # specs) never need to reimplement `mirror`'s path handling independently.
  # A prior independent reimplementation in the system specs drifted out of
  # sync with the Windows drive-letter substitution here, producing a
  # still-colon-containing path that's invalid on Windows (`Errno::EINVAL`)
  # even though the path this class actually wrote to was correct all along.
  describe '#snapshot_file / #diagnosis_file' do
    it 'returns exactly the path #write_snapshot writes to' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' )

      expect( @tree.snapshot_file( 'debug', '/proj/foo.o' ) ).to eq( @files.keys.first )
    end

    it 'returns exactly the path #write_diagnosis writes to' do
      @tree.write_diagnosis( 'debug', '/proj/foo.o', { 'target' => '/proj/foo.o' } )

      expect( @tree.diagnosis_file( 'debug', '/proj/foo.o' ) ).to eq( @files.keys.first )
    end

    it 'strips a Windows drive letter colon the same way #write_snapshot does' do
      @tree.write_snapshot( 'C:/build/.dep_cache_debug', 'C:\\proj\\src\\foo.c', hash: 'abc' )
      real_path = @files.keys.first

      expect( @tree.snapshot_file( 'C:/build/.dep_cache_debug', 'C:\\proj\\src\\foo.c' ) ).to eq( real_path )
      # Only debug_root's own leading drive letter contributes a colon --
      # the mirrored target path contributes none.
      expect( real_path.count(':') ).to eq(1)
    end
  end

  describe '#write_diagnosis' do
    it 'writes a diagnosis document that is not conflated with a snapshot' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' )
      @tree.write_diagnosis( 'debug', '/proj/foo.o', { 'target' => '/proj/foo.o', 'self' => { 'changed' => true } } )

      # Both files exist side by side under the same target directory.
      snapshot_path = @files.keys.find { |p| p.end_with?('snapshot.yml') }
      diagnosis_path = @files.keys.find { |p| p.end_with?('diagnosis.yml') }

      expect( File.dirname( snapshot_path ) ).to eq( File.dirname( diagnosis_path ) )
      expect( YAML.safe_load( @files[diagnosis_path] )['self'] ).to eq( 'changed' => true )
    end
  end

  describe '#prune' do
    it 'removes a snapshotted path\'s entire debug directory' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'abc' )
      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' ) ).not_to be_nil

      @tree.prune( 'debug', '/proj/foo.o' )

      expect( @tree.read_snapshot( 'debug', '/proj/foo.o' ) ).to be_nil
    end

    it 'does not affect a different path\'s debug directory' do
      @tree.write_snapshot( 'debug', '/proj/foo.o', hash: 'foo-hash' )
      @tree.write_snapshot( 'debug', '/proj/bar.o', hash: 'bar-hash' )

      @tree.prune( 'debug', '/proj/foo.o' )

      expect( @tree.read_snapshot( 'debug', '/proj/bar.o' )['hash'] ).to eq('bar-hash')
    end

    it 'is harmless to call for a path that was never snapshotted' do
      expect { @tree.prune( 'debug', '/proj/never-captured.o' ) }.not_to raise_error
    end
  end

end
