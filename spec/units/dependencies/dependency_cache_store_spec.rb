# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'ceedling/file_wrapper'
require 'ceedling/loginator'
require 'ceedling/dependencies/dependency_cache_store'

VALID_SELF_HASH = 'a' * 64
VALID_META_HASH = 'b' * 64
VALID_DEP_HASH  = 'c' * 64

describe DependencyCacheStore do

  before(:each) do
    @file_wrapper = instance_double('FileWrapper')
    @loginator = instance_double('Loginator')
    allow( @loginator ).to receive(:log)

    # Default: an entry's target "exists on disk" unless a specific test says
    # otherwise -- keeps every other test in this file from having to stub
    # existence for every target key it happens to use, now that `load` also
    # checks target existence for pruning purposes (see the "entry pruning"
    # examples below). `stub_file` below overrides this per-path as needed.
    allow( @file_wrapper ).to receive(:exist?).and_return(true)

    @store = described_class.new( { :file_wrapper => @file_wrapper, :loginator => @loginator } )
  end

  def stub_file(path, content)
    allow( @file_wrapper ).to receive(:exist?).with(path).and_return(true)
    allow( @file_wrapper ).to receive(:read).with(path).and_return(content)
  end

  def valid_entry
    { 'self_hash' => VALID_SELF_HASH, 'meta_hash' => VALID_META_HASH, 'deps' => { 'foo.h' => VALID_DEP_HASH } }
  end

  def valid_payload(entries)
    JSON.generate(
      'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
      'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
      'entries'        => entries
    )
  end

  describe '#load' do
    it 'returns an empty store when the file does not exist' do
      allow( @file_wrapper ).to receive(:exist?).with('cache.json').and_return(false)

      result = @store.load('cache.json')

      expect( result ).to eq(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => {},
        'pruned'         => []
      )
    end

    it 'never touches the real filesystem -- only the injected FileWrapper' do
      expect( @file_wrapper ).to receive(:exist?).with('cache.json').and_return(false)
      @store.load('cache.json')
    end

    it 'loads a well-formed cache and keeps its valid entries' do
      stub_file( 'cache.json', valid_payload( 'foo.o' => valid_entry ) )

      result = @store.load('cache.json')

      expect( result['entries'] ).to eq( 'foo.o' => valid_entry )
      expect( @loginator ).not_to have_received(:log)
    end

    it 'treats syntactically invalid JSON as an absent cache and logs a warning' do
      stub_file( 'cache.json', '{ this is not json' )

      result = @store.load('cache.json')

      expect( result['entries'] ).to eq( {} )
      expect( @loginator ).to have_received(:log)
    end

    it 'treats a top-level JSON value that is not an object as an absent cache' do
      stub_file( 'cache.json', JSON.generate( ['not', 'an', 'object'] ) )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'treats a missing schema_version as an absent cache' do
      payload = JSON.generate(
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => { 'foo.o' => valid_entry }
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'treats a newer schema_version as an absent cache (not a compatibility range)' do
      payload = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION + 1,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => { 'foo.o' => valid_entry }
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'treats an older schema_version as an absent cache (not a compatibility range)' do
      payload = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION - 1,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => { 'foo.o' => valid_entry }
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'treats a mismatched hash_algorithm as an absent cache' do
      payload = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
        'hash_algorithm' => 'md5',
        'entries'        => { 'foo.o' => valid_entry }
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'treats a non-object entries field as an absent cache' do
      payload = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => 'not an object'
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( {} )
    end

    it 'drops only a malformed individual entry, keeping other valid entries (self_hash wrong format)' do
      bad = valid_entry.merge( 'self_hash' => 'not-a-hex-digest' )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad, 'good.o' => valid_entry ) )

      result = @store.load('cache.json')

      expect( result['entries'].keys ).to eq( ['good.o'] )
      expect( @loginator ).to have_received(:log)
    end

    it 'drops an entry with a self_hash of the wrong length' do
      bad = valid_entry.merge( 'self_hash' => 'abc123' )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'drops an entry with an uppercase self_hash (hex digest must be lowercase)' do
      bad = valid_entry.merge( 'self_hash' => VALID_SELF_HASH.upcase )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'accepts a nil meta_hash (meta is optional)' do
      entry = valid_entry.merge( 'meta_hash' => nil )
      stub_file( 'cache.json', valid_payload( 'foo.o' => entry ) )

      expect( @store.load('cache.json')['entries'] ).to eq( 'foo.o' => entry )
    end

    it 'drops an entry with a malformed (non-nil, non-hex) meta_hash' do
      bad = valid_entry.merge( 'meta_hash' => 'nonsense' )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'drops an entry whose deps field is not an object' do
      bad = valid_entry.merge( 'deps' => ['foo.h'] )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'drops an entry with a malformed dependency hash' do
      bad = valid_entry.merge( 'deps' => { 'foo.h' => 'not-a-digest' } )
      stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'drops an entry that is not an object at all' do
      stub_file( 'cache.json', valid_payload( 'bad.o' => 'not an object' ) )

      expect( @store.load('cache.json')['entries'] ).to be_empty
    end

    it 'tolerates unknown extra keys on an otherwise-valid entry (forward compatibility)' do
      entry = valid_entry.merge( 'debug_tier' => 1, 'debug_meta' => { 'flags' => ['-O2'] } )
      stub_file( 'cache.json', valid_payload( 'foo.o' => entry ) )

      expect( @store.load('cache.json')['entries'] ).to eq( 'foo.o' => entry )
    end

    it 'tolerates unknown top-level keys (forward compatibility)' do
      payload = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries'        => { 'foo.o' => valid_entry },
        'some_future_field' => 'ignored'
      )
      stub_file( 'cache.json', payload )

      expect( @store.load('cache.json')['entries'] ).to eq( 'foo.o' => valid_entry )
    end

    describe 'entry pruning (targets deleted from disk)' do
      it 'silently drops an otherwise-valid entry whose target no longer exists on disk' do
        stub_file( 'cache.json', valid_payload( 'deleted.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)

        expect( @store.load('cache.json')['entries'] ).to be_empty
      end

      it 'keeps a valid entry whose target still exists' do
        stub_file( 'cache.json', valid_payload( 'still-here.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('still-here.o').and_return(true)

        expect( @store.load('cache.json')['entries'] ).to eq( 'still-here.o' => valid_entry )
      end

      it 'prunes only the deleted target, keeping a separate still-existing entry' do
        payload = valid_payload( 'deleted.o' => valid_entry, 'still-here.o' => valid_entry )
        stub_file( 'cache.json', payload )
        allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)
        allow( @file_wrapper ).to receive(:exist?).with('still-here.o').and_return(true)

        expect( @store.load('cache.json')['entries'] ).to eq( 'still-here.o' => valid_entry )
      end

      it 'does not log a "malformed" warning for a pruned (merely deleted) entry -- it is routine, not corruption' do
        stub_file( 'cache.json', valid_payload( 'deleted.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)

        @store.load('cache.json')

        expect( @loginator ).not_to have_received(:log).with( a_string_matching(/malformed/i), any_args )
      end

      it 'logs pruning only at a quiet (OBNOXIOUS) verbosity, unlike the COMPLAIN-level malformed-entry warning' do
        stub_file( 'cache.json', valid_payload( 'deleted.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)

        @store.load('cache.json')

        expect( @loginator ).to have_received(:log).with( anything, Verbosity::OBNOXIOUS, anything )
      end

      it 'never prunes based on target existence alone -- a malformed entry is still dropped and warned about even if its target exists' do
        bad = valid_entry.merge( 'self_hash' => 'not-a-hex-digest' )
        stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )
        allow( @file_wrapper ).to receive(:exist?).with('bad.o').and_return(true)

        expect( @store.load('cache.json')['entries'] ).to be_empty
        expect( @loginator ).to have_received(:log).with( a_string_matching(/malformed/i), any_args )
      end

      # `pruned` is what DependencyTracker#open uses to also clean up
      # DependencyDebugTree data for the same targets -- both a deleted
      # target and a malformed entry must be reported, since either way
      # there's no valid cache entry left to explain.
      it 'reports a deleted target in the returned pruned list' do
        stub_file( 'cache.json', valid_payload( 'deleted.o' => valid_entry, 'kept.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)
        allow( @file_wrapper ).to receive(:exist?).with('kept.o').and_return(true)

        expect( @store.load('cache.json')['pruned'] ).to eq( ['deleted.o'] )
      end

      it 'reports a malformed entry in the returned pruned list too' do
        bad = valid_entry.merge( 'self_hash' => 'not-a-hex-digest' )
        stub_file( 'cache.json', valid_payload( 'bad.o' => bad ) )
        allow( @file_wrapper ).to receive(:exist?).with('bad.o').and_return(true)

        expect( @store.load('cache.json')['pruned'] ).to eq( ['bad.o'] )
      end

      it 'reports an empty pruned list when nothing was dropped' do
        stub_file( 'cache.json', valid_payload( 'kept.o' => valid_entry ) )
        allow( @file_wrapper ).to receive(:exist?).with('kept.o').and_return(true)

        expect( @store.load('cache.json')['pruned'] ).to eq( [] )
      end
    end
  end

  describe '#persist' do
    it 'writes to a temp file in the same directory, then renames into place' do
      allow( @file_wrapper ).to receive(:dirname).with('/build/dep_cache.json').and_return('/build')
      allow( @file_wrapper ).to receive(:mkdir).with('/build')

      write_path = nil
      write_content = nil
      allow( @file_wrapper ).to receive(:write) do |path, content|
        write_path = path
        write_content = content
      end

      mv_from = nil
      mv_to = nil
      allow( @file_wrapper ).to receive(:mv) do |from, to|
        mv_from = from
        mv_to = to
      end

      @store.persist( '/build/dep_cache.json', { 'foo.o' => valid_entry } )

      expect( @file_wrapper ).to have_received(:mkdir).with('/build')
      expect( write_path ).to start_with('/build/dep_cache.json.tmp.')
      expect( mv_from ).to eq( write_path )
      expect( mv_to ).to eq('/build/dep_cache.json')

      parsed = JSON.parse( write_content )
      expect( parsed['schema_version'] ).to eq( DependencyCacheStore::CACHE_SCHEMA_VERSION )
      expect( parsed['hash_algorithm'] ).to eq( DependencyHasher::HASH_ALGORITHM )
      expect( parsed['entries'] ).to eq( 'foo.o' => valid_entry )
    end

    it 'never writes directly to the final path (always via temp + rename)' do
      allow( @file_wrapper ).to receive(:dirname).and_return('/build')
      allow( @file_wrapper ).to receive(:mkdir)
      allow( @file_wrapper ).to receive(:write)
      allow( @file_wrapper ).to receive(:mv)

      expect( @file_wrapper ).not_to receive(:write).with('/build/dep_cache.json', anything)

      @store.persist( '/build/dep_cache.json', {} )
    end
  end

end
