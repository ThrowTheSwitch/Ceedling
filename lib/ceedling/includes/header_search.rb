# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'

# Directory listings of headers, each indexed by filename, listed once and shared by a
# search and its views
class HeaderListings

  def initialize(lister)
    @lister = lister
    @by_dir = {}
    @lock   = Mutex.new
  end

  # A directory's headers
  def headers(dir)
    return entry( dir ).first
  end

  # The header named `name` in `dir`, letter case and all, or nil
  def named(dir, name)
    return entry( dir ).last[name]
  end

  private

  # A directory's headers and the same headers by filename, the first of a name kept
  def entry(dir)
    listed = @lock.synchronize { @by_dir[dir] }
    return listed unless listed.nil?

    headers = @lister.call( dir )
    names   = headers.each_with_object( {} ) { |header, by_name| by_name[File.basename( header )] ||= header }
    return @lock.synchronize { @by_dir[dir] ||= [headers, names].freeze }
  end

end

# A test's real headers, found the way its compiler finds them: each search path in
# order, joined with the path an #include names. A bare name joins to a search path's
# own listing, so it finds exactly the headers a flat listing of every search path holds.
#
# An #include after stage 4 can carry a path the test never wrote: GCC's resolved
# path for a plain #include, or a mock's place below its mirror root. When no search
# path joins to a query, the query matches the trailing path of a header directly in a
# search path, and then names a header itself when one lies below a search path. A
# mock's place is measured from its mirror root, so its search tries the trailing match
# first (`trailing_first`).
#
# Each directory is listed once for the search's lifetime, so one search serves a
# test's every lookup in one stage.
class HeaderSearch

  # Characters a directory listing would read as a glob
  GLOB_CHARACTERS = /[*?\[\]{}]/

  attr_reader :paths

  # A query as every search reads it: forward slashes, with no `.` or empty segments. A
  # drive letter, a root `/`, and a Windows share's `//` stay.
  def self.normalized(query)
    query = query.to_s.tr( '\\', '/' )
    root  = query[%r{\A(?:[A-Za-z]:/|/+)}].to_s
    rest  = query.delete_prefix( root )
    root  = (ProjectPaths.unc?( root ) ? '//' : '/') if root.start_with?( '/' )

    return root + ProjectPaths.segments( rest ).join( '/' )
  end

  # `paths` in search order. `lister` gives a directory's headers. `refusals` explain, by
  # the query a test's #include asks for, why no search path reaches its header.
  def initialize(paths, lister, trailing_first: false, listings: nil, refusals: {})
    @paths          = paths
    @trailing_first = trailing_first
    @listings       = listings || HeaderListings.new( lister )
    @refusals       = refusals.to_h { |query, why| [normalized( query ), why] }
  end

  # The same search, trying a header's trailing path before a join, for a mock whose
  # #include names its place below its mirror root
  def trailing_first
    return HeaderSearch.new( @paths, nil, trailing_first: true, listings: @listings, refusals: @refusals )
  end

  # The headers `query` names, the one the compiler includes first. Empty for none.
  def header_candidates(query)
    query = normalized( query )
    tiers = @trailing_first ? [:trailing, :joined, :named] : [:joined, :trailing, :named]

    # A bare name names no directory, so only a join can find it
    tiers.each do |tier|
      next if tier != :joined and File.dirname( query ) == '.'

      found = send( tier, query )
      return distinct( found ) unless found.empty?
    end

    return []
  end

  # Whether a search path joined with `text` names a header, as the compiler's -I does
  def joins?(text)
    return !joined( normalized( text ) ).empty?
  end

  # Every header a search for `query` looked at, for a hint at one in another letter case
  def hint_files(query)
    query = normalized( query )
    dirs  = joinable?( query ) ? @paths.map { |path| joined_directory( path, query ) } : []
    dirs << File.dirname( query ) if nameable?( query )

    return (dirs.flat_map { |dir| listing( dir ) } + flat).uniq
  end

  # Why no search path reaches the header `query` names, for the error its failed lookup
  # raises. Nil when Ceedling refused no search path for it.
  def refusal(query)
    return @refusals[normalized( query )]
  end

  # The header at `path` itself, as its directory lists it, or nil. A preprocessor's #include
  # names its header by such a path, which a search path joined with it could name another by.
  def at(path)
    path = normalized( path )
    return nameable?( path ) ? named_in( File.dirname( path ), File.basename( path ) ) : nil
  end

  # The #include text through which these search paths find `header` first, as the compiler
  # joins it with each: `preferring` when that does, then its filename, otherwise its path below
  # the earliest search path that does. Nil for none.
  def spelling(header, preferring: nil)
    target = location( header )
    texts  = [preferring, File.basename( header )] + @paths.filter_map { |path| ProjectPaths.subdir_below( path, header ) }

    return texts.compact.uniq.find do |text|
      found = joined( normalized( text ) ).first
      !found.nil? and location( found ) == target
    end
  end

  # Every header directly in a search path, in search order
  def flat
    return @flat ||= @paths.flat_map { |path| listing( path ) }.uniq
  end

  private

  def normalized(query)
    return HeaderSearch.normalized( query )
  end

  # Each search path joined with the query's path, holding the query's file
  def joined(query)
    return [] unless joinable?( query )

    name = File.basename( query )
    return @paths.filter_map { |path| named_in( joined_directory( path, query ), name ) }
  end

  # A header directly in a search path whose trailing path is the query
  def trailing(query)
    return PathMatcher.candidates( query, flat )
  end

  # The query itself, when it names a header at or below a search path
  def named(query)
    return [] unless @paths.any? { |path| ProjectPaths.contains?( path, File.dirname( query ) ) }

    return [at( query )].compact
  end

  # A relative path the compiler would join: no `..` and no glob character in its
  # directory, which a listing would expand
  def joinable?(query)
    return false if PathMatcher.absolute?( query ) or File.dirname( query ).match?( GLOB_CHARACTERS )

    return !ProjectPaths.segments( query ).include?( '..' )
  end

  def nameable?(query)
    dir = File.dirname( query )
    return (dir != '.' and !dir.match?( GLOB_CHARACTERS ))
  end

  def joined_directory(path, query)
    dir = File.dirname( query )
    return dir == '.' ? path : File.join( path, dir )
  end

  # One header reached through two spellings of one directory is one candidate
  def distinct(found)
    return found if found.length < 2

    return found.uniq { |header| location( header ) }
  end

  def location(header)
    absolute = ProjectPaths.absolute( header )
    return ProjectPaths::WINDOWS ? absolute.downcase : absolute
  end

  def named_in(dir, name)
    return @listings.named( dir, name )
  end

  def listing(dir)
    return @listings.headers( dir )
  end

end
