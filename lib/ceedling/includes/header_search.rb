# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'

# A test's real headers, found the way its compiler finds them: each search path in
# order, joined with the path an #include names. A bare name joins to a search path's
# own listing, so it finds exactly the headers a flat listing of every search path holds.
#
# An #include after stage 4 can carry a path the test never wrote: GCC's resolved
# path for a plain #include, or a mock's place below its mirror root. When no search
# path joins to a query, the query matches the trailing path of a header directly in a
# search path, and then names a header itself when one lies below a search path.
#
# Each directory is listed once for the search's lifetime, so one search serves a
# test's every lookup in one stage.
class HeaderSearch

  # Characters a directory listing would read as a glob
  GLOB_CHARACTERS = /[*?\[\]{}]/

  attr_reader :paths

  # `paths` in search order. `lister` gives a directory's headers.
  def initialize(paths, lister)
    @paths    = paths
    @lister   = lister
    @listings = {}
    @lock     = Mutex.new
  end

  # The headers `query` names, the one the compiler includes first. Empty for none.
  def header_candidates(query)
    query = normalized( query )

    found = joined( query )
    found = trailing( query ) if found.empty? and with_directory?( query )
    found = named( query ) if found.empty? and with_directory?( query )

    return distinct( found )
  end

  # Every header a search for `query` looked at, for a hint at one in another letter case
  def hint_files(query)
    query = normalized( query )
    dirs  = joinable?( query ) ? @paths.map { |path| joined_directory( path, query ) } : []
    dirs << File.dirname( query ) if with_directory?( query )

    return (dirs.flat_map { |dir| listing( dir ) } + flat).uniq
  end

  # The #include text through which these search paths find `header` first: its filename
  # when that does, otherwise its path below the earliest search path that does. Nil for none.
  def spelling(header)
    target = location( header )
    texts  = [File.basename( header )] + @paths.filter_map { |path| ProjectPaths.subdir_below( path, header ) }

    return texts.uniq.find do |text|
      found = header_candidates( text ).first
      !found.nil? and location( found ) == target
    end
  end

  # Every header directly in a search path, in search order
  def flat
    return @flat ||= @paths.flat_map { |path| listing( path ) }.uniq
  end

  private

  def normalized(query)
    query    = query.to_s.tr( '\\', '/' )
    absolute = query[%r{\A(?:[A-Za-z]:)?/}].to_s
    return absolute + ProjectPaths.segments( query ).join( '/' )
  end

  # Each search path joined with the query's path, holding the query's file
  def joined(query)
    return [] unless joinable?( query )

    name = File.basename( query )
    return @paths.filter_map do |path|
      listing( joined_directory( path, query ) ).find { |header| File.basename( header ) == name }
    end
  end

  # A header directly in a search path whose trailing path is the query
  def trailing(query)
    return PathMatcher.candidates( query, flat )
  end

  # The query itself, when it names a header at or below a search path
  def named(query)
    dir = File.dirname( query )
    return [] unless @paths.any? { |path| ProjectPaths.contains?( path, dir ) }

    name = File.basename( query )
    return listing( dir ).select { |header| File.basename( header ) == name }
  end

  # A relative path the compiler would join: no `..`, which the scan resolves against
  # the test file's own directory, and no glob character
  def joinable?(query)
    return false if PathMatcher.absolute?( query ) or query.match?( GLOB_CHARACTERS )

    return !ProjectPaths.segments( query ).include?( '..' )
  end

  def with_directory?(query)
    return File.dirname( query ) != '.'
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

  def listing(dir)
    listed = @lock.synchronize { @listings[dir] }
    return listed unless listed.nil?

    listed = @lister.call( dir )
    return @lock.synchronize { @listings[dir] ||= listed }
  end

end
