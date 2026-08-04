# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'
require 'ceedling/file_wrapper'
require 'ceedling/system_wrapper'
require 'ceedling/loginator'
require 'ceedling/yaml_wrapper'
require 'ceedling/dependencies/dependency_hasher'
require 'ceedling/dependencies/dependency_path_normalizer'
require 'ceedling/dependencies/dependency_cache_store'
require 'ceedling/dependencies/gcc_dependency_parser'
require 'ceedling/dependencies/dependency_debug_tree'
require 'ceedling/dependencies/dependency_differ'
require 'ceedling/dependencies/dependency_tracker'

# DependencyTracker is exercised here with its real (small, deterministic)
# collaborators -- DependencyHasher, DependencyPathNormalizer,
# DependencyCacheStore, GccDependencyParser, DependencyDebugTree,
# DependencyDiffer -- wired to a mocked FileWrapper, SystemWrapper, and
# Loginator. Those collaborators each have their own exhaustive unit specs
# for internal edge cases; here the goal is verifying DependencyTracker's
# actual end-to-end behavior through its public API without a single real
# file ever touched.
describe DependencyTracker do

  before(:each) do
    @file_wrapper = instance_double('FileWrapper')
    @system_wrapper = instance_double('SystemWrapper')
    @loginator = instance_double('Loginator')
    allow( @loginator ).to receive(:log)

    # Default: paths pass through unchanged and nothing exists yet -- most
    # tests only need to stub `exist?`/`read` true for the specific paths
    # they care about.
    # Path normalization defaults: real DependencyPathNormalizer is used (see
    # below), but with an empty on-disk directory listing so it always reduces
    # to a harmless passthrough (`normalize(path) == path`) -- its own case-
    # sensitivity-handling edge cases already have a dedicated, exhaustive spec.
    allow( @file_wrapper ).to receive(:get_expanded_path) { |path| path }
    allow( @file_wrapper ).to receive(:dirname) { |path| File.dirname( path ) }
    allow( @file_wrapper ).to receive(:basename) { |path, ext = nil| ext ? File.basename( path, ext ) : File.basename( path ) }
    allow( @file_wrapper ).to receive(:extname) { |path| File.extname( path ) }
    allow( @file_wrapper ).to receive(:directory_listing).and_return([])
    allow( @file_wrapper ).to receive(:exist?).and_return(false)
    allow( @file_wrapper ).to receive(:mkdir)
    allow( @file_wrapper ).to receive(:write)
    allow( @file_wrapper ).to receive(:mv)
    allow( @system_wrapper ).to receive(:env_get).with('CEEDLING_DEP_DEBUG').and_return(nil)

    hasher = DependencyHasher.new( { :file_wrapper => @file_wrapper } )
    normalizer = DependencyPathNormalizer.new( { :file_wrapper => @file_wrapper } )
    normalizer.setup()
    cache_store = DependencyCacheStore.new( { :file_wrapper => @file_wrapper, :loginator => @loginator } )
    gcc_parser = GccDependencyParser.new
    debug_tree = DependencyDebugTree.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => YamlWrapper.new } )
    differ = DependencyDiffer.new

    @tracker = described_class.new(
      {
        :file_wrapper => @file_wrapper,
        :system_wrapper => @system_wrapper,
        :loginator => @loginator,
        :dependency_hasher => hasher,
        :dependency_path_normalizer => normalizer,
        :dependency_cache_store => cache_store,
        :gcc_dependency_parser => gcc_parser,
        :dependency_debug_tree => debug_tree,
        :dependency_differ => differ
      }
    )
    @tracker.setup()
  end

  def stub_file(path, content)
    allow( @file_wrapper ).to receive(:exist?).with(path).and_return(true)
    # :read backs .d-file and debug-snapshot reading (text); :read_binary
    # backs DependencyHasher's content hashing. Both are stubbed to the same
    # content since these tests don't exercise the distinction FileWrapper
    # itself draws between the two.
    allow( @file_wrapper ).to receive(:read).with(path).and_return(content)
    allow( @file_wrapper ).to receive(:read_binary).with(path).and_return(content)
  end

  def open_tracker(store_path: 'cache.json', debug_tier: nil)
    allow( @file_wrapper ).to receive(:exist?).with(store_path).and_return(false)
    @tracker.open( store_path: store_path, debug_tier: debug_tier )
  end

  # ── #open / guard against use before #open ─────────────────────────────

  describe 'use before #open' do
    it 'raises for #register' do
      expect { @tracker.register('foo.o', files: []) }.to raise_error( CeedlingException )
    end

    it 'raises for #stale?' do
      expect { @tracker.stale?('foo.o') }.to raise_error( CeedlingException )
    end

    it 'raises for #mark_fresh' do
      expect { @tracker.mark_fresh('foo.o') }.to raise_error( CeedlingException )
    end

    it 'raises for #invalidate' do
      expect { @tracker.invalidate('foo.o') }.to raise_error( CeedlingException )
    end

    it 'raises for #flush' do
      expect { @tracker.flush }.to raise_error( CeedlingException )
    end
  end

  describe '#open' do
    it 'starts with an empty cache when no cache file exists yet' do
      open_tracker
      stub_file( 'foo.o', 'binary' )
      @tracker.register( 'foo.o', files: [] )

      expect( @tracker.stale?('foo.o') ).to be(true)
    end
  end

  # ── #register additive semantics ────────────────────────────────────────

  describe '#register' do
    before(:each) { open_tracker }

    it 'unions files across repeated registrations for the same target instead of replacing them' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )
      stub_file( 'foo.h', 'header' )

      @tracker.register( 'foo.o', files: ['foo.c'] )
      @tracker.register( 'foo.o', files: ['foo.h'] )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)

      # Changing either previously-registered dependency's content makes it stale,
      # proving both survived the two separate register() calls.
      stub_file( 'foo.h', 'header CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'deduplicates a file registered more than once for the same target' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )

      @tracker.register( 'foo.o', files: ['foo.c'] )
      @tracker.register( 'foo.o', files: ['foo.c'] )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)
    end

    it 'shallow-merges meta across repeated registrations, later calls winning on conflicting keys' do
      stub_file( 'foo.o', 'obj' )

      @tracker.register( 'foo.o', meta: { coverage: true, opt_level: 0 } )
      @tracker.register( 'foo.o', meta: { opt_level: 2 } )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)

      # A fresh tracker instance re-registering with only the *merged* result
      # should be recognized as equivalent -- proving the merge actually happened
      # (coverage survived, opt_level was overwritten to 2, not left at 0 or duplicated).
      @tracker.invalidate( 'foo.o' )
      @tracker.register( 'foo.o', meta: { coverage: true, opt_level: 2 } )
      @tracker.mark_fresh( 'foo.o' )
      expect( @tracker.stale?('foo.o') ).to be(false)
    end
  end

  # ── gcc -M/-MM/-MMD ingestion ────────────────────────────────────────────

  describe '#register_gcc_deps_string' do
    before(:each) { open_tracker }

    it 'additively registers every target discovered in the parsed content' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )
      stub_file( 'foo.h', 'header' )

      @tracker.register_gcc_deps_string( "foo.o: foo.c foo.h\n" )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)

      stub_file( 'foo.h', 'header CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'applies the same meta to every target discovered in the content' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'bar.h', 'header' ) # -MP-style phony target with no deps

      @tracker.register_gcc_deps_string( "foo.o: bar.h\n\nbar.h:\n", meta: { opt_level: 2 } )
      @tracker.mark_fresh( 'foo.o' )
      @tracker.mark_fresh( 'bar.h' )

      expect( @tracker.stale?('foo.o') ).to be(false)
      expect( @tracker.stale?('bar.h') ).to be(false)
    end

    it 'is additive alongside an explicit #register call for the same target' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )
      stub_file( 'foo.h', 'header' )

      @tracker.register( 'foo.o', files: ['foo.c'] )
      @tracker.register_gcc_deps_string( "foo.o: foo.h\n" )
      @tracker.mark_fresh( 'foo.o' )

      stub_file( 'foo.c', 'source CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end
  end

  describe '#register_gcc_deps_file' do
    before(:each) { open_tracker }

    it 'reads the .d file via FileWrapper and registers its targets' do
      stub_file( 'build/foo.d', "foo.o: foo.c\n" )
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )

      @tracker.register_gcc_deps_file( 'build/foo.d' )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)

      stub_file( 'foo.c', 'source CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end
  end

  # ── #stale? ──────────────────────────────────────────────────────────────

  describe '#stale?' do
    before(:each) { open_tracker }

    it 'is stale when never registered' do
      expect( @tracker.stale?('never-registered.o') ).to be(true)
    end

    it 'is stale when the target itself does not exist on disk' do
      @tracker.register( 'missing.o', files: [] )
      expect( @tracker.stale?('missing.o') ).to be(true)
    end

    it 'is stale when registered and existing but never marked fresh' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )

      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'is not stale immediately after being marked fresh, with no changes' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.c', 'source' )
      @tracker.register( 'foo.o', files: ['foo.c'] )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)
    end

    it 'is stale again if the target file itself changes' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )

      stub_file( 'foo.o', 'obj CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'is stale again if a dependency changes' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.h', 'header' )
      @tracker.register( 'foo.o', files: ['foo.h'] )
      @tracker.mark_fresh( 'foo.o' )

      stub_file( 'foo.h', 'header CHANGED' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'is stale if a previously-existing dependency disappears' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.h', 'header' )
      @tracker.register( 'foo.o', files: ['foo.h'] )
      @tracker.mark_fresh( 'foo.o' )

      allow( @file_wrapper ).to receive(:exist?).with('foo.h').and_return(false)
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'is stale again if meta changes' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', meta: { opt_level: 0 } )
      @tracker.mark_fresh( 'foo.o' )

      @tracker.register( 'foo.o', meta: { opt_level: 2 } )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'does not mutate any state -- a pure query, repeatable' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )

      expect( @tracker.stale?('foo.o') ).to be(false)
      expect( @tracker.stale?('foo.o') ).to be(false)
    end
  end

  # ── #mark_fresh ──────────────────────────────────────────────────────────

  describe '#mark_fresh' do
    before(:each) { open_tracker }

    it 'omits a currently-missing dependency from the recorded deps rather than raising' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: ['missing.h'] )

      expect { @tracker.mark_fresh('foo.o') }.not_to raise_error
      # A target with an unrecorded (missing) dep is still correctly stale on next check,
      # since `stale?` independently treats a missing registered dep as stale.
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    # These write/read a real (mocked-FileWrapper-backed) DependencyDebugTree
    # snapshot rather than anything embedded in the JSON cache -- Tier 2's
    # capture moved out of the cache entries entirely. A small in-memory
    # fake file store lets snapshots actually round-trip (write, then read
    # back) within these examples; `stub_file` for specific paths (the
    # target/dependency content itself) still takes precedence over it.
    context 'debug tiers' do
      before(:each) do
        @debug_files = {}
        allow( @file_wrapper ).to receive(:write) { |path, content| @debug_files[path] = content }
        allow( @file_wrapper ).to receive(:read) { |path| @debug_files.fetch( path ) { raise "unstubbed read: #{path}" } }
        allow( @file_wrapper ).to receive(:read_binary) { |path| @debug_files.fetch( path ) { raise "unstubbed read_binary: #{path}" } }
        allow( @file_wrapper ).to receive(:exist?) { |path| @debug_files.key?( path ) }
      end

      def read_snapshot(path)
        debug_tree = DependencyDebugTree.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => YamlWrapper.new } )
        debug_tree.read_snapshot( @tracker.instance_variable_get(:@debug_root), path )
      end

      it 'writes no snapshot at all by default (tier :none)' do
        stub_file( 'foo.o', 'obj' )
        @tracker.register( 'foo.o', meta: { opt_level: 2 } )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o') ).to be_nil
      end

      it 'writes a snapshot with canonicalized meta at tier :meta, without any file content' do
        open_tracker( debug_tier: :meta )

        stub_file( 'foo.o', 'obj' )
        @tracker.register( 'foo.o', meta: { opt_level: 2, coverage: true } )
        @tracker.mark_fresh( 'foo.o' )

        snapshot = read_snapshot('foo.o')
        expect( snapshot['meta'] ).to eq( 'coverage' => true, 'opt_level' => 2 )
        expect( snapshot ).not_to have_key('content')
      end

      it 'additionally captures both target and dependency file content at tier :full' do
        open_tracker( debug_tier: :full )

        stub_file( 'foo.o', 'obj content' )
        stub_file( 'foo.h', 'header content' )
        @tracker.register( 'foo.o', files: ['foo.h'] )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o')['content'] ).to eq('obj content')
        expect( read_snapshot('foo.h')['content'] ).to eq('header content')
      end

      it 'does not snapshot a dependency at tier :meta -- only the target (with its meta) gets one' do
        open_tracker( debug_tier: :meta )

        stub_file( 'foo.o', 'obj' )
        stub_file( 'foo.h', 'header' )
        @tracker.register( 'foo.o', files: ['foo.h'] )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o') ).not_to be_nil
        expect( read_snapshot('foo.h') ).to be_nil
      end

      it 'truncates (rather than including or silently dropping) an oversized file at tier :full' do
        open_tracker( debug_tier: :full )

        huge = 'x' * (DependencyTracker::DEBUG_FULL_CAPTURE_SIZE_CAP + 1)
        stub_file( 'foo.o', huge )
        @tracker.register( 'foo.o', files: [] )
        @tracker.mark_fresh( 'foo.o' )

        snapshot = read_snapshot('foo.o')
        expect( snapshot['truncated'] ).to be(true)
        expect( snapshot['size'] ).to eq( huge.bytesize )
        expect( snapshot ).not_to have_key('content')
      end

      it 'resolves debug tier from the CEEDLING_DEP_DEBUG environment variable when not given explicitly' do
        allow( @system_wrapper ).to receive(:env_get).with('CEEDLING_DEP_DEBUG').and_return('meta')
        open_tracker

        stub_file( 'foo.o', 'obj' )
        @tracker.register( 'foo.o', meta: { a: 1 } )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o') ).not_to be_nil
      end

      it 'falls back to :none for an unrecognized CEEDLING_DEP_DEBUG value' do
        allow( @system_wrapper ).to receive(:env_get).with('CEEDLING_DEP_DEBUG').and_return('nonsense')
        open_tracker

        stub_file( 'foo.o', 'obj' )
        @tracker.register( 'foo.o', meta: { a: 1 } )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o') ).to be_nil
      end

      it 'an explicit debug_tier argument to #open takes precedence over the environment variable' do
        allow( @system_wrapper ).to receive(:env_get).with('CEEDLING_DEP_DEBUG').and_return('full')
        open_tracker( debug_tier: :none )

        stub_file( 'foo.o', 'obj' )
        @tracker.register( 'foo.o', files: [] )
        @tracker.mark_fresh( 'foo.o' )

        expect( read_snapshot('foo.o') ).to be_nil
      end
    end
  end

  # ── #invalidate ──────────────────────────────────────────────────────────

  describe '#invalidate' do
    before(:each) { open_tracker }

    it 'makes a previously-fresh target stale again' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )
      expect( @tracker.stale?('foo.o') ).to be(false)

      @tracker.invalidate( 'foo.o' )
      expect( @tracker.stale?('foo.o') ).to be(true)
    end

    it 'does not affect other targets' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'bar.o', 'obj2' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.register( 'bar.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )
      @tracker.mark_fresh( 'bar.o' )

      @tracker.invalidate( 'foo.o' )

      expect( @tracker.stale?('bar.o') ).to be(false)
    end

    it 'is harmless to call for a target with no cache entry' do
      expect { @tracker.invalidate('never-marked-fresh.o') }.not_to raise_error
    end
  end

  # ── #flush ───────────────────────────────────────────────────────────────

  describe '#flush' do
    before(:each) { open_tracker }

    it 'persists via DependencyCacheStore to the store_path given to #open' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )

      write_path = nil
      allow( @file_wrapper ).to receive(:dirname).and_return('.')
      allow( @file_wrapper ).to receive(:write) { |path, _content| write_path = path }

      @tracker.flush

      expect( write_path ).to start_with('cache.json.tmp.')
    end

    # `prune:` is the opt-in hook for a caller that knows this run's
    # registrations are the complete, current target set (see the class
    # comment on #flush). A cache entry left over for a target this run
    # never registered -- simulated directly here rather than via a real
    # two-process round trip, which spec/system/dependencies covers -- is
    # exactly the scenario `prune:` exists to handle.
    context 'prune: option' do
      it 'keeps a cache entry for a target not registered this run by default (prune: false)' do
        stub_file( 'kept.o', 'kept' )
        @tracker.register( 'kept.o', files: [] )
        @tracker.mark_fresh( 'kept.o' )
        seed_cache_entry( 'orphan.o' )

        expect( last_persisted_entries.keys ).to contain_exactly( 'kept.o', 'orphan.o' )
      end

      it 'drops a cache entry for a target not registered this run when prune: true' do
        stub_file( 'kept.o', 'kept' )
        @tracker.register( 'kept.o', files: [] )
        @tracker.mark_fresh( 'kept.o' )
        seed_cache_entry( 'orphan.o' )

        expect( last_persisted_entries( prune: true ).keys ).to eq( ['kept.o'] )
      end

      it 'prune: true also mutates in-memory state, not just what is persisted on that one call' do
        stub_file( 'kept.o', 'kept' )
        @tracker.register( 'kept.o', files: [] )
        @tracker.mark_fresh( 'kept.o' )
        seed_cache_entry( 'orphan.o' )

        last_persisted_entries( prune: true ) # first flush, pruning requested

        # A second flush with no prune requested: if pruning had only affected
        # what was written the first time (not in-memory state), 'orphan.o'
        # would reappear here.
        expect( last_persisted_entries.keys ).to eq( ['kept.o'] )
      end

      it 'keeps a target that is registered this run even if mark_fresh has not been called yet this run' do
        # e.g. fresh from an earlier run's cache entry, registered again this
        # run (as a real build step would), but not yet rebuilt/re-marked-fresh.
        seed_cache_entry( 'in-progress.o' )
        @tracker.register( 'in-progress.o', files: [] )

        expect( last_persisted_entries( prune: true ).keys ).to eq( ['in-progress.o'] )
      end
    end
  end

  # ── #diagnose ────────────────────────────────────────────────────────────

  describe '#diagnose' do
    before(:each) do
      open_tracker
      # A small in-memory fake file store so a snapshot written by mark_fresh
      # within an example can actually be read back by diagnose later in
      # that same example -- `stub_file` for specific paths (target/
      # dependency content) still takes precedence over this generic
      # fallback for its own exact path.
      @debug_files = {}
      allow( @file_wrapper ).to receive(:write) { |path, content| @debug_files[path] = content }
      allow( @file_wrapper ).to receive(:mv) { |from, to| @debug_files[to] = @debug_files.delete( from ) }
      allow( @file_wrapper ).to receive(:read) { |path| @debug_files.fetch( path ) { raise "unstubbed read: #{path}" } }
      allow( @file_wrapper ).to receive(:read_binary) { |path| @debug_files.fetch( path ) { raise "unstubbed read_binary: #{path}" } }
      allow( @file_wrapper ).to receive(:exist?) { |path| @debug_files.key?( path ) }
    end

    # Reads back diagnosis.yml through the real DependencyDebugTree, proving
    # #diagnose actually persisted it (not just returned it in-memory).
    def read_diagnosis(target)
      tree = DependencyDebugTree.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => YamlWrapper.new } )
      allow( @file_wrapper ).to receive(:read) { |path| @debug_files.fetch( path ) { raise "unstubbed read: #{path}" } }
      allow( @file_wrapper ).to receive(:read_binary) { |path| @debug_files.fetch( path ) { raise "unstubbed read_binary: #{path}" } }
      allow( @file_wrapper ).to receive(:exist?) { |path| @debug_files.key?( path ) }
      tree.send( :read_yaml, tree.send( :path_dir, @tracker.instance_variable_get(:@debug_root), target ) + '/diagnosis.yml' )
    end

    it 'reports why when the target was never registered this run' do
      diagnosis = @tracker.diagnose( 'never-registered.o' )

      expect( diagnosis['target'] ).to eq('never-registered.o')
      expect( diagnosis['reason'] ).to match(/never registered/i)
    end

    it 'reports why when the target does not exist on disk' do
      @tracker.register( 'missing.o', files: [] )

      expect( @tracker.diagnose('missing.o')['reason'] ).to match(/does not exist on disk/i)
    end

    it 'reports why when there is no prior cache entry (never marked fresh)' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )

      expect( @tracker.diagnose('foo.o')['reason'] ).to match(/never marked fresh/i)
    end

    it 'reports self/meta/antecedents as unchanged for a target that is not stale' do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.h', 'header' )
      @tracker.register( 'foo.o', files: ['foo.h'], meta: { a: 1 } )
      @tracker.mark_fresh( 'foo.o' )

      diagnosis = @tracker.diagnose( 'foo.o' )

      expect( diagnosis['self']['changed'] ).to be(false)
      expect( diagnosis['meta']['changed'] ).to be(false)
      expect( diagnosis['antecedents'] ).to eq( [ { 'path' => 'foo.h', 'changed' => false } ] )
    end

    it "reports a 'no snapshot' reason for changed self content when tier was :none at mark_fresh time" do
      stub_file( 'foo.o', 'original' )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' ) # tier :none -- no snapshot captured

      stub_file( 'foo.o', 'changed' )

      diagnosis = @tracker.diagnose( 'foo.o' )
      expect( diagnosis['self']['changed'] ).to be(true)
      expect( diagnosis['self']['reason'] ).to match(/no prior snapshot/i)
    end

    it 'produces a real content diff for changed self content when tier was :full at mark_fresh time' do
      open_tracker( debug_tier: :full )
      stub_file( 'foo.o', "original\n" )
      @tracker.register( 'foo.o', files: [] )
      @tracker.mark_fresh( 'foo.o' )

      stub_file( 'foo.o', "changed\n" )

      diagnosis = @tracker.diagnose( 'foo.o' )
      expect( diagnosis['self']['changed'] ).to be(true)
      expect( diagnosis['self']['diff'] ).to include('original')
      expect( diagnosis['self']['diff'] ).to include('changed')
    end

    it 'produces a real meta diff when tier was :meta at mark_fresh time' do
      open_tracker( debug_tier: :meta )
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', meta: { opt_level: 0 } )
      @tracker.mark_fresh( 'foo.o' )

      @tracker.register( 'foo.o', meta: { opt_level: 2 } )

      diagnosis = @tracker.diagnose( 'foo.o' )
      # The wrapper's own boolean must survive being merged with diff_meta's
      # output -- diff_meta deliberately returns 'changed_keys', not
      # 'changed', to avoid colliding with and clobbering this flag.
      expect( diagnosis['meta']['changed'] ).to be(true)
      expect( diagnosis['meta']['changed_keys'] ).to eq( 'opt_level' => { 'old' => 0, 'new' => 2 } )
    end

    it "flags a dependency that no longer exists as missing, rather than diffing it" do
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.h', 'header' )
      @tracker.register( 'foo.o', files: ['foo.h'] )
      @tracker.mark_fresh( 'foo.o' )

      allow( @file_wrapper ).to receive(:exist?).with('foo.h').and_return(false)

      antecedent = @tracker.diagnose( 'foo.o' )['antecedents'].first
      expect( antecedent ).to eq( 'path' => 'foo.h', 'missing' => true )
    end

    it 'produces a real content diff for a changed dependency when tier was :full at mark_fresh time' do
      open_tracker( debug_tier: :full )
      stub_file( 'foo.o', 'obj' )
      stub_file( 'foo.h', "original header\n" )
      @tracker.register( 'foo.o', files: ['foo.h'] )
      @tracker.mark_fresh( 'foo.o' )

      stub_file( 'foo.h', "changed header\n" )

      antecedent = @tracker.diagnose( 'foo.o' )['antecedents'].first
      expect( antecedent['path'] ).to eq('foo.h')
      expect( antecedent['changed'] ).to be(true)
      expect( antecedent['diff'] ).to include('original header')
      expect( antecedent['diff'] ).to include('changed header')
    end

    it 'persists the diagnosis to the debug tree, not just returning it in-memory' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )

      @tracker.diagnose( 'foo.o' )

      persisted = read_diagnosis( 'foo.o' )
      expect( persisted['target'] ).to eq('foo.o')
    end

    it 'works even when no debug tier was ever active -- diagnosis is not itself gated behind a tier' do
      stub_file( 'foo.o', 'obj' )
      @tracker.register( 'foo.o', files: [] )

      expect { @tracker.diagnose('foo.o') }.not_to raise_error
    end
  end

  # ── Debug tree pruning wiring ────────────────────────────────────────────
  # Confirms DependencyTracker actually calls DependencyDebugTree#prune for
  # targets dropped by each of the two pruning mechanisms (see
  # DependencyCacheStore#load and #flush(prune:)), so the debug tree never
  # outlives the cache entries it exists to explain. DependencyCacheStore's
  # and DependencyDebugTree's own internals already have exhaustive specs;
  # this is specifically about the wiring between them and the tracker.
  describe 'debug tree pruning wiring' do
    before(:each) do
      @debug_files = {}
      allow( @file_wrapper ).to receive(:write) { |path, content| @debug_files[path] = content }
      allow( @file_wrapper ).to receive(:mv) { |from, to| @debug_files[to] = @debug_files.delete( from ) }
      allow( @file_wrapper ).to receive(:read) { |path| @debug_files.fetch( path ) { raise "unstubbed read: #{path}" } }
      allow( @file_wrapper ).to receive(:read_binary) { |path| @debug_files.fetch( path ) { raise "unstubbed read_binary: #{path}" } }
      allow( @file_wrapper ).to receive(:rm_rf) { |path| @debug_files.reject! { |p, _| p == path || p.start_with?( "#{path}/" ) } }
      # A "directory" (as opposed to a specific written file) exists if any
      # file under it does -- mirrors real filesystem semantics, needed
      # because #prune checks `exist?` on a directory, not a file.
      allow( @file_wrapper ).to receive(:exist?) { |path| @debug_files.key?( path ) || @debug_files.keys.any? { |p| p.start_with?( "#{path}/" ) } }
    end

    def seed_debug_snapshot(store_path, target)
      debug_tree = DependencyDebugTree.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => YamlWrapper.new } )
      debug_tree.write_snapshot( debug_root_for( store_path ), target, hash: 'a' * 64 )
    end

    def debug_snapshot_exists?(store_path, target)
      debug_tree = DependencyDebugTree.new( { :file_wrapper => @file_wrapper, :yaml_wrapper => YamlWrapper.new } )
      !debug_tree.read_snapshot( debug_root_for( store_path ), target ).nil?
    end

    def debug_root_for(store_path)
      @file_wrapper.dirname( store_path ) + '/' + @file_wrapper.basename( store_path, @file_wrapper.extname( store_path ) ) + '_debug'
    end

    it 'prunes debug tree data for a target load-time-pruned because its file was deleted from disk' do
      seed_debug_snapshot( 'cache.json', 'deleted.o' )
      expect( debug_snapshot_exists?( 'cache.json', 'deleted.o' ) ).to be(true)

      cache_json = JSON.generate(
        'schema_version' => DependencyCacheStore::CACHE_SCHEMA_VERSION,
        'hash_algorithm' => DependencyHasher::HASH_ALGORITHM,
        'entries' => { 'deleted.o' => { 'self_hash' => 'a' * 64, 'meta_hash' => nil, 'deps' => {} } }
      )
      allow( @file_wrapper ).to receive(:exist?).with('cache.json').and_return(true)
      allow( @file_wrapper ).to receive(:exist?).with('deleted.o').and_return(false)
      allow( @file_wrapper ).to receive(:read).with('cache.json').and_return( cache_json )

      @tracker.open( store_path: 'cache.json' )

      expect( debug_snapshot_exists?( 'cache.json', 'deleted.o' ) ).to be(false)
    end

    it 'prunes debug tree data for a target dropped by flush(prune: true)' do
      open_tracker
      seed_debug_snapshot( 'cache.json', 'orphan.o' )
      expect( debug_snapshot_exists?( 'cache.json', 'orphan.o' ) ).to be(true)

      seed_cache_entry( 'orphan.o' ) # in-memory cache entry, as if loaded from a prior run
      stub_file( 'kept.o', 'kept' )
      @tracker.register( 'kept.o', files: [] )

      @tracker.flush( prune: true )

      expect( debug_snapshot_exists?( 'cache.json', 'orphan.o' ) ).to be(false)
    end

    it 'does not prune debug tree data for a target flush(prune: true) keeps' do
      open_tracker
      seed_debug_snapshot( 'cache.json', 'kept.o' )
      stub_file( 'kept.o', 'kept' )
      @tracker.register( 'kept.o', files: [] )
      @tracker.mark_fresh( 'kept.o' )

      @tracker.flush( prune: true )

      expect( debug_snapshot_exists?( 'cache.json', 'kept.o' ) ).to be(true)
    end
  end

  def seed_cache_entry(target)
    @tracker.instance_variable_get(:@cache)['entries'][target] = {
      'self_hash' => 'a' * 64, 'meta_hash' => nil, 'deps' => {}
    }
  end

  def last_persisted_entries(prune: false)
    allow( @file_wrapper ).to receive(:dirname).and_return('.')
    written = nil
    allow( @file_wrapper ).to receive(:write) { |_path, content| written = content }
    allow( @file_wrapper ).to receive(:mv)

    @tracker.flush( prune: prune )

    JSON.parse( written )['entries']
  end

end
