# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/file_wrapper'
require 'ceedling/dependencies/dependency_path_normalizer'

describe DependencyPathNormalizer do

  before(:each) do
    @file_wrapper = instance_double('FileWrapper')
    @normalizer = described_class.new( { :file_wrapper => @file_wrapper } )
    @normalizer.setup()
  end

  # A fake, in-memory `dirname`/`basename`/`directory_listing` filesystem so specs
  # never touch a real disk. `tree` maps an absolute directory path to the list of
  # entry basenames actually "on disk" in that directory (i.e. real, on-disk casing).
  def stub_tree(tree)
    allow( @file_wrapper ).to receive(:dirname) { |path| File.dirname( path ) }
    allow( @file_wrapper ).to receive(:basename) { |path| File.basename( path ) }
    allow( @file_wrapper ).to receive(:get_expanded_path) { |path| path }
    allow( @file_wrapper ).to receive(:exist?) { |path| true }

    allow( @file_wrapper ).to receive(:directory_listing) do |glob|
      dir = File.dirname( glob )
      (tree[dir] || []).map { |entry| File.join( dir, entry ) }
    end
  end

  it 'expands the path even when it does not exist on disk' do
    allow( @file_wrapper ).to receive(:get_expanded_path).with('rel/foo.c').and_return('/proj/rel/foo.c')
    allow( @file_wrapper ).to receive(:exist?).with('/proj/rel/foo.c').and_return(false)

    expect( @normalizer.normalize('rel/foo.c') ).to eq('/proj/rel/foo.c')
  end

  it 'returns the path unchanged when the on-disk casing already matches exactly' do
    stub_tree(
      '/' => ['proj'],
      '/proj' => ['foo.c']
    )

    expect( @normalizer.normalize('/proj/foo.c') ).to eq('/proj/foo.c')
  end

  it 'recovers the real on-disk casing when the caller-supplied casing differs (case-insensitive filesystem)' do
    stub_tree(
      '/' => ['proj'],
      '/proj' => ['Foo.c']
    )

    expect( @normalizer.normalize('/proj/foo.c') ).to eq('/proj/Foo.c')
  end

  it 'recovers real casing across multiple path components' do
    stub_tree(
      '/' => ['Proj'],
      '/Proj' => ['Src'],
      '/Proj/Src' => ['Foo.c']
    )

    expect( @normalizer.normalize('/proj/src/foo.c') ).to eq('/Proj/Src/Foo.c')
  end

  it 'falls back to the expanded path when the directory listing has no matching entry at all' do
    stub_tree(
      '/' => ['proj'],
      '/proj' => ['bar.c'] # a totally different file -- not even a case variant of what was asked for
    )

    expect( @normalizer.normalize('/proj/foo.c') ).to eq('/proj/foo.c')
  end

  it 'prefers an exact-case match over a case-insensitive one when both exist (case-sensitive filesystem, genuinely distinct files)' do
    stub_tree(
      '/' => ['proj'],
      '/proj' => ['Foo.c', 'foo.c'] # two distinct, coexisting files differing only in case
    )

    expect( @normalizer.normalize('/proj/foo.c') ).to eq('/proj/foo.c')
    expect( @normalizer.normalize('/proj/Foo.c') ).to eq('/proj/Foo.c')
  end

  it 'falls back to the expanded path when the directory listing cannot be read (e.g. permissions error)' do
    allow( @file_wrapper ).to receive(:get_expanded_path).and_return('/proj/foo.c')
    allow( @file_wrapper ).to receive(:exist?).and_return(true)
    allow( @file_wrapper ).to receive(:dirname) { |path| File.dirname( path ) }
    allow( @file_wrapper ).to receive(:basename) { |path| File.basename( path ) }
    allow( @file_wrapper ).to receive(:directory_listing).and_raise( Errno::EACCES )

    expect( @normalizer.normalize('/proj/foo.c') ).to eq('/proj/foo.c')
  end

  it 'memoizes a directory listing rather than re-listing it for every lookup in that directory' do
    stub_tree(
      '/' => ['proj'],
      '/proj' => ['Foo.c', 'Bar.c']
    )

    @normalizer.normalize('/proj/foo.c')
    @normalizer.normalize('/proj/bar.c')

    expect( @file_wrapper ).to have_received(:directory_listing).with('/proj/*').once
  end

end
