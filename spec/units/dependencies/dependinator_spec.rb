# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/dependencies/dependency_tracker'
require 'ceedling/dependencies/dependinator'

describe Dependinator do

  before(:each) do
    @tracker = instance_double('DependencyTracker')
    @dependinator = described_class.new( { :dependency_tracker => @tracker } )
    stub_const('PROJECT_BUILD_DEPENDENCIES_CACHE_PATH', '/proj/build/cache')
  end

  describe '#open' do
    it 'opens the tracker at a cache file beneath the project dependencies cache path' do
      expect( @tracker ).to receive(:open).with( store_path: '/proj/build/cache/.dep_cache.json' )
      @dependinator.open
    end
  end

  describe '#register' do
    it 'passes target, files, and meta straight through to the tracker' do
      expect( @tracker ).to receive(:register).with( 'foo.o', files: ['foo.c'], meta: { opt: 2 } )
      @dependinator.register( 'foo.o', files: ['foo.c'], meta: { opt: 2 } )
    end

    it 'defaults files and meta to empty when not given, matching the tracker\'s own defaults' do
      expect( @tracker ).to receive(:register).with( 'foo.o', files: [], meta: {} )
      @dependinator.register( 'foo.o' )
    end
  end

  describe '#register_gcc_deps_file' do
    it 'passes filepath and meta straight through to the tracker' do
      expect( @tracker ).to receive(:register_gcc_deps_file).with( 'foo.d', meta: { opt: 2 } )
      @dependinator.register_gcc_deps_file( 'foo.d', meta: { opt: 2 } )
    end
  end

  describe '#stale?' do
    it 'returns whatever the tracker reports for the target' do
      allow( @tracker ).to receive(:stale?).with('foo.o').and_return(true)
      expect( @dependinator.stale?('foo.o') ).to be(true)
    end
  end

  describe '#mark_fresh' do
    it 'delegates to the tracker' do
      expect( @tracker ).to receive(:mark_fresh).with('foo.o')
      @dependinator.mark_fresh('foo.o')
    end
  end

  describe '#invalidate' do
    it 'delegates to the tracker' do
      expect( @tracker ).to receive(:invalidate).with('foo.o')
      @dependinator.invalidate('foo.o')
    end
  end

  describe '#flush' do
    it 'does not prune the tracker cache when refresh_dependencies is not requested (the default)' do
      expect( @tracker ).to receive(:flush).with( prune: false )
      @dependinator.flush
    end

    it 'does not prune when refresh_dependencies is explicitly false (a partial build, e.g. test:pattern)' do
      expect( @tracker ).to receive(:flush).with( prune: false )
      @dependinator.flush( refresh_dependencies: false )
    end

    it 'prunes the tracker cache when refresh_dependencies is requested (a full test:all run)' do
      expect( @tracker ).to receive(:flush).with( prune: true )
      @dependinator.flush( refresh_dependencies: true )
    end
  end

end
