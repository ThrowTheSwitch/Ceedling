# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'pathname'
require 'fileutils'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/exceptions'
require 'ceedling/filesystem/project_paths'
require 'ceedling/filesystem/path_spellings'
require 'ceedling/filesystem/path_exclusions'


class FilePathCollectionUtils

  # One collected directory: its spelling through its entry's real base, both of its
  # spellings, and how far below the nearest base of an entry naming it it lies
  Named = Struct.new( :spelled, :spellings, :distance )

  constructor :file_wrapper

  # The directories one or more (+:/-:) paths and globs name, once each, spelled through
  # each entry's base as the base really is, as an #include or a test name reaches them. A
  # `-:` entry drops the directories it names and every directory below them, except one an
  # additive entry naming it names nearer. Each path in `exclude` does so too, except where
  # an entry naming a directory is based no farther away. Each path in `reserved`, and every
  # directory below it, is never collected.
  def collect_paths(paths, exclude: [], reserved: [])
    # Nil input (e.g. unconfigured section) is treated as an empty list
    return [] if paths.nil?

    additive, subtractive = paths.partition { |entry| FilePathUtils.add_path?( entry ) }
    minus = PathExclusions.of( directories_of( subtractive ), exclude, reserved )

    kept = named_directories( additive ).select { |named| minus.keeps?( named.spellings, named.distance ) }
    return kept.map { |named| ProjectPaths.relative( named.spelled ) }
  end

  # Given a file list, add to it or remove from it considering (+:/-:) aggregation operators.
  # Rake's FileList does not robustly handle relative filepaths and patterns.
  # So, we rebuild the FileList ourselves and return it. A revision adds no file below a
  # path in `exclude` unless the revision is based no farther away, and none below a path in
  # `reserved` at all.
  def revise_filelist(list, revisions, exclude: [], reserved: [])
    # Nil list produces an empty FileList; nil revisions leaves the list unchanged
    return FileList.new([]) if list.nil?

    additive, subtractive = (revisions || []).partition { |revision| FilePathUtils.add_path?( revision ) }
    kept = kept_files( list, additive, subtractive, PathExclusions.of( [], exclude, reserved ) )

    # #104 -- every entry here is already a concrete, real file, but plain FileList.new or
    # #include re-reads each as a glob, silently dropping a literal `[`/`]`.
    # FileWrapper#instantiate_file_list_literal adds every entry as-is.
    result = @file_wrapper.instantiate_file_list_literal( kept.map { |path| ProjectPaths.relative( path ) } )
    result.resolve() # Force expansion to prevent race conditions in threaded context
    return result
  end

  # The places files below `entries` mirror below, each spelled canonically: the base of a
  # `/**` or `/*` entry, every directory a glob within an entry names, or the entry itself.
  # A `-:` exclusion roots nothing. A `[`/`]` is part of a name (#104), never a glob.
  def collect_mirror_roots(entries)
    return [] if entries.nil?

    roots = entries.select { |entry| FilePathUtils.add_path?( entry ) }.flat_map { |entry| entry_roots( entry ) }
    return roots.map { |root| ProjectPaths.canonical( root ) }.uniq
  end

  # A path relative to the working directory, or absolute when it has no relative form
  def shortest_path_from_working(path)
    return ProjectPaths.relative( ProjectPaths.absolute( path ) )
  end

  private

  # Every directory additive entries name, once each by its real spelling, with its distance
  # below the nearest base of the entries naming it
  def named_directories(entries)
    named = {}
    entries.each do |entry|
      bases = PathSpellings.of( [FilePathUtils.no_decorators( entry )] )
      entry_directories( entry ).each { |dir| name_directory( named, dir, bases ) }
    end

    return named.values
  end

  # Records `dir`, the first spelling of its real place kept, nearer if these bases are
  def name_directory(named, dir, bases)
    both  = [dir, ProjectPaths.real_absolute( dir )]
    found = (named[PathSpellings.key( both.last )] ||= Named.new( dir, both, Float::INFINITY ))
    found.distance = [found.distance, PathSpellings.nearer( both, bases )].min
  end

  # The listed files and those additive revisions name, less those `-:` revisions name, each
  # compared through its directory as it really is
  def kept_files(list, additive, subtractive, excluded)
    real  = {}
    minus = Set.new( files_of( subtractive ).map { |path| real_key( path, real ) } )
    added = added_files( additive, excluded, real )
    return (list.map { |path| ProjectPaths.absolute( path ) } + added).uniq { |path| real_key( path, real ) }.reject { |path| minus.include?( real_key( path, real ) ) }
  end

  # The files additive revisions name that `excluded` keeps, each judged by its distance
  # below the base of the revision naming it
  def added_files(additive, excluded, real)
    return files_of( additive ) if excluded.none?

    return additive.flat_map do |revision|
      bases = PathSpellings.of( [FilePathUtils.no_decorators( revision )] )
      revision_files( revision ).select do |file|
        spellings = [file, real_spelling( file, real )]
        excluded.keeps?( spellings, PathSpellings.nearer( spellings, bases ) )
      end
    end
  end

  def directories_of(entries)
    return entries.flat_map { |entry| entry_directories( entry ) }
  end

  def files_of(revisions)
    return revisions.flat_map { |revision| revision_files( revision ) }
  end

  # Every directory one entry names, absolute and spelled through its base as the base
  # really is, so one place is never collected under two spellings of that base
  def entry_directories(entry)
    path = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( entry ) )
    dirs = listed_directories( path )
    dirs = with_parents( dirs, path ) if path.end_with?( '/**', '/*' )

    return PathSpellings.through_real( dirs.map { |dir| ProjectPaths.absolute( dir ) }, ProjectPaths.absolute( FilePathUtils.no_decorators( path ) ) )
  end

  # #104 -- FilePathUtils.subdirectory_glob escapes a literal `[`/`]` in the path itself, so
  # it's matched literally rather than read as glob syntax. Sorted for Github Issue #860.
  def listed_directories(path)
    entries = @file_wrapper.directory_listing( FilePathUtils.subdirectory_glob( path ) ).sort
    return entries.select { |entry| @file_wrapper.directory?( entry ) }
  end

  # Ceedling's recursive glob convention includes the directory above each match, unlike
  # Ruby's, and the base directory itself when nothing below it matches
  def with_parents(dirs, path)
    parents = dirs.map { |dir| File.join( dir, '..' ) }
    parents << FilePathUtils.no_decorators( path ) if dirs.empty?
    return parents + dirs
  end

  def entry_roots(entry)
    path = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( entry ) ).sub( %r{(?:/\*\*?)+\z}, '' )
    return [path] unless path.match?( /[*?{]/ )

    listing = @file_wrapper.directory_listing( FilePathUtils.escape_glob_brackets( path ) )
    return listing.sort.select { |listed| @file_wrapper.directory?( listed ) }
  end

  # Every file one :files revision names, absolute and spelled through its base as the base
  # really is. #104 -- a literal `[`/`]` is escaped as in `listed_directories`.
  def revision_files(revision)
    path  = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( revision ) )
    files = @file_wrapper.directory_listing( FilePathUtils.escape_glob_brackets( path ) ).sort.reject { |entry| @file_wrapper.directory?( entry ) }

    return PathSpellings.through_real( files.map { |file| ProjectPaths.absolute( file ) }, ProjectPaths.absolute( FilePathUtils.no_decorators( path ) ) )
  end

  # A file compared through its directory as it really is, keeping its own name. Each
  # directory is resolved once per call, in `real`.
  def real_key(file, real)
    return PathSpellings.key( real_spelling( file, real ) )
  end

  def real_spelling(file, real)
    dir = File.dirname( file )
    return File.join( (real[dir] ||= ProjectPaths.real_absolute( dir )), File.basename( file ) )
  end

end
