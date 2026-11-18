# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/header_search'
require 'ceedling/includes/includes'

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

    it "keeps a preferred text that finds the header first" do
      headers = search( ['src', 'src/app', 'src/hw'], ['src/app/config.h', 'src/hw/config.h'] )

      expect(headers.spelling( 'src/app/config.h', preferring: 'app/config.h' )).to eq( 'app/config.h' )
    end

    # The compiler only joins a text with each search path
    it "passes over a preferred text the search paths reach only by its trailing path" do
      headers = search( ['src/hw', 'lib'], ['src/hw/config.h', 'lib/app/config.h'] )

      expect(headers.spelling( 'src/hw/config.h', preferring: 'hw/config.h' )).to eq( 'config.h' )
    end

    it "passes over a preferred text that finds another header" do
      headers = search( ['src', 'src/app', 'src/hw'], ['src/app/config.h', 'src/hw/config.h'] )

      expect(headers.spelling( 'src/hw/config.h', preferring: 'config.h' )).to eq( 'hw/config.h' )
    end
  end

  describe "#at" do
    it "gives the header a path names itself, whatever a search path joins that path to" do
      headers = search( ['include', 'third_party/mylib'], ['include/config.h', 'third_party/mylib/include/config.h'] )

      expect(headers.at( 'include/config.h' )).to eq( 'include/config.h' )
      expect(headers.header_candidates( 'include/config.h' ).first).to eq( 'third_party/mylib/include/config.h' )
    end

    it "gives nil where no header lies at the path" do
      expect(search( ['src'], ['src/foo.h'] ).at( 'src/bar.h' )).to be_nil
    end
  end

  # A generated file writes a header's #include by the text that reaches it, and a Partial
  # matches modules by the header the include names
  describe "Include#spelled_by" do
    it "spells a user #include as the search paths reach its header, and names that header" do
      spelled = UserInclude.new( 'drivers/foo.h' ).spelled_by( search( ['src'], ['src/drivers/foo.h'] ) )

      expect( [spelled.filepath, spelled.include_path, spelled.to_s] ).to eq( ['src/drivers/foo.h', 'drivers/foo.h', '#include "drivers/foo.h"'] )
    end

    it "keeps the filename where it reaches the same header" do
      spelled = UserInclude.new( 'src/foo.h' ).spelled_by( search( ['src'], ['src/foo.h'] ) )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['src/foo.h', '#include "foo.h"'] )
    end

    it "keeps an #include's anchoring" do
      spelled = UserInclude.new( 'src/foo.h', directory_relative: true ).spelled_by( search( ['src'], ['src/foo.h'] ) )

      expect( spelled.directory_relative? ).to be( true )
    end

    # A preprocessor's #include holds the path the compiler found its header by
    it "names a resolved #include's own header, never one a later search path joins its path to" do
      headers = search( ['include', 'third_party/mylib'], ['include/config.h', 'third_party/mylib/include/config.h'] )
      spelled = UserInclude.new( 'include/config.h' ).spelled_by( headers, resolved: true )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['include/config.h', '#include "config.h"'] )
    end

    # A list that was never resolved, or a path in another letter case, names no header itself
    it "takes the search paths' header for a resolved #include with no header at its path" do
      spelled = UserInclude.new( 'drivers/foo.h' ).spelled_by( search( ['src'], ['src/drivers/foo.h'] ), resolved: true )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['src/drivers/foo.h', '#include "drivers/foo.h"'] )
    end

    it "leaves a resolved #include whose header no directory lists as it is" do
      lost = UserInclude.new( 'gone/foo.h' )

      expect( lost.spelled_by( search( ['src'], ['src/foo.h'] ), resolved: true ) ).to equal( lost )
    end

    # Reconciliation spells two same-named headers apart, which a shorter text could undo
    it "keeps the text an #include has where that text reaches its header" do
      headers = search( ['src', 'src/app', 'src/hw'], ['src/app/config.h', 'src/hw/config.h'] )
      spelled = UserInclude.new( 'src/app/config.h', include_path: 'app/config.h' ).spelled_by( headers, resolved: true )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['src/app/config.h', '#include "app/config.h"'] )
    end

    # A text scan's #include holds the text as written, which the compiler looks for beside the
    # file holding it before any search path
    it "names the header beside its includer first for an #include as written" do
      headers = search( ['src', 'src/drivers/uart'], ['src/config.h', 'src/drivers/uart/config.h'] )
      spelled = UserInclude.new( 'config.h' ).spelled_by( headers, from: 'src/drivers/uart' )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['src/drivers/uart/config.h', '#include "drivers/uart/config.h"'] )
    end

    it "takes the search paths' header for an #include as written with no header beside its includer" do
      headers = search( ['src', 'src/drivers/uart'], ['src/config.h', 'src/drivers/uart/config.h'] )
      spelled = UserInclude.new( 'config.h' ).spelled_by( headers, from: 'src/drivers' )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['src/config.h', '#include "config.h"'] )
    end

    # The compiler finds the search paths' header from where a generated file lives
    it "spells an #include as written by the search paths' header where none reaches the one beside its includer" do
      headers = search( ['src'], ['src/drivers/foo.h', 'test/drivers/foo.h'] )
      spelled = UserInclude.new( 'drivers/foo.h' ).spelled_by( headers, from: 'test' )

      expect( [spelled.filepath, spelled.to_s] ).to eq( ['test/drivers/foo.h', '#include "drivers/foo.h"'] )
    end

    it "takes an anchored #include's own header, never one beside its includer" do
      headers = search( ['src'], ['src/common/helper.h', 'src/x/common/helper.h'] )
      spelled = UserInclude.new( 'src/common/helper.h', directory_relative: true ).spelled_by( headers, from: 'src/x' )

      expect( spelled.filepath ).to eq( 'src/common/helper.h' )
    end

    it "leaves a system #include, a mock's, and one whose header it can't find as they are" do
      headers = search( ['src'], ['src/foo.h'] )
      system  = SystemInclude.new( 'stdint.h' )
      mock    = MockInclude.new( 'mock_foo.h' )
      lost    = UserInclude.new( 'gone.h' )

      expect( [system, mock, lost].map { |include| include.spelled_by( headers ) } ).to eq( [system, mock, lost] )
      expect( lost.spelled_by( headers ) ).to equal( lost )
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
