# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/header_search'

describe HeaderSearch do
  # A directory tree's headers, listed as IncludePathinator lists a directory
  def search(paths, tree)
    @listed = Hash.new( 0 )
    lister  = lambda do |dir|
      @listed[dir] += 1
      tree.select { |header| File.dirname( header ) == dir }.sort
    end

    return described_class.new( paths, lister )
  end

  describe "#header_candidates" do
    it "finds a bare name in the first search path holding it, the others after it" do
      headers = search( ['inc', 'src'], ['src/foo.h', 'inc/foo.h', 'src/bar.h'] )

      expect(headers.header_candidates( 'foo.h' )).to eq( ['inc/foo.h', 'src/foo.h'] )
    end

    it "finds a bare name exactly as a trailing match over every search path's listing does" do
      tree    = ['a/x.h', 'a/y.h', 'b/x.h', 'b/sub/x.h', 'c/z.h']
      headers = search( ['b', 'a', 'c'], tree )
      flat    = ['b', 'a', 'c'].flat_map { |dir| tree.select { |header| File.dirname( header ) == dir }.sort }

      %w[x.h y.h z.h w.h].each do |name|
        expect(headers.header_candidates( name )).to eq( PathMatcher.candidates( name, flat ) )
      end
    end

    it "joins each search path with the directory an #include names" do
      headers = search( ['src'], ['src/drivers/foo.h'] )

      expect(headers.header_candidates( 'drivers/foo.h' )).to eq( ['src/drivers/foo.h'] )
    end

    it "finds the same path below two search paths in search order" do
      headers = search( ['b', 'a'], ['a/drivers/foo.h', 'b/drivers/foo.h'] )

      expect(headers.header_candidates( 'drivers/foo.h' )).to eq( ['b/drivers/foo.h', 'a/drivers/foo.h'] )
    end

    it "prefers a join over a header whose trailing path matches" do
      headers = search( ['lib/drivers', 'src'], ['lib/drivers/foo.h', 'src/drivers/foo.h'] )

      expect(headers.header_candidates( 'drivers/foo.h' )).to eq( ['src/drivers/foo.h'] )
    end

    it "drops a leading ./ and empty segments from the #include" do
      headers = search( ['src'], ['src/drivers/foo.h'] )

      expect(headers.header_candidates( './drivers//foo.h' )).to eq( ['src/drivers/foo.h'] )
    end

    it "gives one header reached through two spellings of its directory once" do
      headers = search( ['src', './src'], ['src/foo.h', './src/foo.h'] )

      expect(headers.header_candidates( 'foo.h' )).to eq( ['src/foo.h'] )
    end

    it "keeps a filename that differs only in letter case out of the candidates" do
      headers = search( ['src'], ['src/drivers/Foo.h'] )

      expect(headers.header_candidates( 'drivers/foo.h' )).to eq( [] )
    end

    # A mock after stage 4 names its place below its mirror root, which need not be a
    # search path
    it "matches the trailing path of a header directly in a search path when no join reaches it" do
      headers = search( ['test/support'], ['test/support/foo.h'] )

      expect(headers.header_candidates( 'support/foo.h' )).to eq( ['test/support/foo.h'] )
    end

    # A plain #include after stage 4 carries the path GCC found it by
    it "takes the #include's own path when it names a header below a search path" do
      headers = search( ['src'], ['src/drivers/foo.h'] )

      expect(headers.header_candidates( 'src/drivers/foo.h' )).to eq( ['src/drivers/foo.h'] )
    end

    it "takes an absolute path below a search path" do
      headers = search( ['/opt/sdk'], ['/opt/sdk/drivers/foo.h'] )

      expect(headers.header_candidates( '/opt/sdk/drivers/foo.h' )).to eq( ['/opt/sdk/drivers/foo.h'] )
    end

    # ProjectPaths expands both sides alike, so a drive-lettered path compares on any host
    it "takes a path with a drive letter below a search path" do
      headers = search( ['C:/sdk/inc'], ['C:/sdk/inc/drivers/x.h'] )

      expect(headers.header_candidates( 'C:\\sdk\\inc\\drivers\\x.h' )).to eq( ['C:/sdk/inc/drivers/x.h'] )
    end

    it "finds no absolute path outside every search path" do
      headers = search( ['src'], ['/opt/sdk/foo.h'] )

      expect(headers.header_candidates( '/opt/sdk/foo.h' )).to eq( [] )
    end

    # The scan resolves `..` against the test file's own directory
    it "never joins a search path with an #include that climbs" do
      headers = search( ['src/a'], ['src/b/foo.h', 'src/a/foo.h'] )

      expect(headers.header_candidates( '../b/foo.h' )).to eq( [] )
    end

    it "never reads a glob character in an #include's directory as a glob" do
      headers = search( ['src', '.'], ['src/drivers/foo.h'] )

      expect(headers.header_candidates( 'd*/foo.h' )).to eq( [] )
      expect(@listed.keys).to_not include( a_string_including( '*' ) )
    end

    it "finds a header whose own name holds a glob character" do
      expect(search( ['src'], ['src/a[1].h'] ).header_candidates( 'a[1].h' )).to eq( ['src/a[1].h'] )
    end

    it "finds nothing for a name no search path reaches" do
      headers = search( ['src'], ['src/foo.h'] )

      expect(headers.header_candidates( 'drivers/bar.h' )).to eq( [] )
    end
  end

  # A mock's #include after stage 4 names its place below its mirror root, which a header
  # of the same path below an earlier search path mustn't take
  describe "#trailing_first" do
    let(:tree) { ['test/support/hal/foo.h', 'inc/hal/foo.h'] }

    it "matches a header directly in a search path by trailing path before joining" do
      headers = search( ['test/support', 'inc', 'inc/hal'], tree )

      expect(headers.header_candidates( 'hal/foo.h' )).to eq( ['test/support/hal/foo.h', 'inc/hal/foo.h'] )
      expect(headers.trailing_first.header_candidates( 'hal/foo.h' )).to eq( ['inc/hal/foo.h'] )
    end

    it "joins when no header's trailing path matches" do
      headers = search( ['src'], ['src/drivers/foo.h'] )

      expect(headers.trailing_first.header_candidates( 'drivers/foo.h' )).to eq( ['src/drivers/foo.h'] )
    end

    it "shares the search's listings" do
      headers = search( ['src'], ['src/foo.h'] )
      headers.header_candidates( 'foo.h' )
      headers.trailing_first.header_candidates( 'foo.h' )

      expect(@listed).to eq( { 'src' => 1 } )
    end
  end

  describe "#refusal" do
    it "explains a query by its own spelling, slashes and dot segments aside" do
      headers = described_class.new( ['src'], ->(_dir) { [] }, refusals: { 'sys/socket.h' => 'why' } )

      expect(headers.refusal( 'sys/socket.h' )).to eq( 'why' )
      expect(headers.refusal( './sys\\socket.h' )).to eq( 'why' )
      expect(headers.refusal( 'socket.h' )).to be_nil
    end

    it "carries over to the trailing-first view" do
      headers = described_class.new( ['src'], ->(_dir) { [] }, refusals: { 'socket.h' => 'why' } )

      expect(headers.trailing_first.refusal( 'socket.h' )).to eq( 'why' )
    end

    it "explains nothing by default" do
      expect(search( ['src'], [] ).refusal( 'socket.h' )).to be_nil
    end
  end

  describe "#joins?" do
    it "says whether a search path joined with the text names a header, as -I does" do
      headers = search( ['src'], ['src/drivers/foo.h'] )

      expect(headers.joins?( 'drivers/foo.h' )).to be( true )
      expect(headers.joins?( 'src/drivers/foo.h' )).to be( false )
    end
  end

  describe "#hint_files" do
    it "holds every header the search looked at, so one in another letter case can be named" do
      headers = search( ['inc', 'src'], ['inc/top.h', 'src/drivers/Foo.h'] )

      expect(headers.hint_files( 'drivers/foo.h' )).to include( 'src/drivers/Foo.h', 'inc/top.h' )
    end
  end

  describe "#spelling" do
    it "spells a header by its filename when the search paths find it by that" do
      expect(search( ['inc', 'src'], ['src/foo.h'] ).spelling( 'src/foo.h' )).to eq( 'foo.h' )
    end

    it "spells a header below a search path by its path below that search path" do
      expect(search( ['src'], ['src/drivers/foo.h'] ).spelling( 'src/drivers/foo.h' )).to eq( 'drivers/foo.h' )
    end

    it "spells a header a same-named one shadows by its filename by its path below a search path" do
      headers = search( ['src', 'src/drivers'], ['src/foo.h', 'src/drivers/foo.h'] )

      expect(headers.spelling( 'src/drivers/foo.h' )).to eq( 'drivers/foo.h' )
    end

    it "gives nil for a header no search path reaches" do
      expect(search( ['src'], ['other/foo.h'] ).spelling( 'other/foo.h' )).to be_nil
    end
  end

  describe "#flat" do
    it "lists every header directly in a search path, in search order" do
      headers = search( ['src', 'inc'], ['inc/a.h', 'src/b.h', 'src/sub/c.h'] )

      expect(headers.flat).to eq( ['src/b.h', 'inc/a.h'] )
    end
  end

  it "lists each directory once however many lookups ask" do
    headers = search( ['src'], ['src/drivers/foo.h', 'src/top.h'] )

    3.times do
      headers.header_candidates( 'drivers/foo.h' )
      headers.header_candidates( 'top.h' )
    end

    expect(@listed).to eq( { 'src/drivers' => 1, 'src' => 1 } )
  end
end
