# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'pathname'
require 'fileutils'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'
require 'ceedling/project_paths'


class FilePathCollectionUtils
  
  constructor :file_wrapper

  # The directories one or more (+:/-:) paths and globs name. A `-:` entry, and each path in
  # `exclude`, drops the directories it names and every directory below them.
  def collect_paths(paths, exclude: [])
    # Nil input (e.g. unconfigured section) is treated as an empty list
    return [] if paths.nil?

    excluded = Set.new( exclude.map { |path| ProjectPaths.absolute( path ) } )
    plus, minus = aggregate( paths, minus: excluded ) { |path| entry_directories( path ) }

    kept = plus.reject { |dir| minus.any? { |root| ProjectPaths.contains?( root, dir ) } }
    return kept.map { |dir| shortest_path_from_working( dir ) }
  end

  # Given a file list, add to it or remove from it considering (+:/-:) aggregation operators.
  # Rake's FileList does not robustly handle relative filepaths and patterns.
  # So, we rebuild the FileList ourselves and return it.
  def revise_filelist(list, revisions)
    # Nil list produces an empty FileList; nil revisions leaves the list unchanged
    return FileList.new([]) if list.nil?

    listed = Set.new( list.map { |path| File.expand_path( path ) } )
    plus, minus = aggregate( revisions || [], plus: listed ) { |revision| revision_files( revision ) }

    # #104 -- every entry here is already a concrete, real file, but plain FileList.new or
    # #include re-reads each as a glob, silently dropping a literal `[`/`]`.
    # FileWrapper#instantiate_file_list_literal adds every entry as-is.
    result = @file_wrapper.instantiate_file_list_literal( (plus - minus).map { |path| shortest_path_from_working( path ) } )
    result.resolve() # Force expansion to prevent race conditions in threaded context
    return result
  end

  # A path relative to the working directory, or absolute when it has no relative form
  def shortest_path_from_working(path)
    return ProjectPaths.relative( File.expand_path( path ) )
  end

  private

  # The paths each entry names, gathered into those to add and those to remove by its decorator
  def aggregate(entries, plus: Set.new, minus: Set.new)
    entries.each { |entry| (FilePathUtils.add_path?( entry ) ? plus : minus).merge( yield( entry ) ) }
    return plus, minus
  end

  # Every directory one entry names, absolute and spelled through its base as the base
  # really is, so one place is never collected under two spellings
  def entry_directories(entry)
    path = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( entry ) )
    dirs = listed_directories( path )
    dirs = with_parents( dirs, path ) if path.end_with?( '/**', '/*' )

    return through_real_base( dirs.map { |dir| File.expand_path( dir ) }, path )
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

  # Every file one :files revision names, absolute and spelled through its base as the base
  # really is. #104 -- a literal `[`/`]` is escaped as in `listed_directories`.
  def revision_files(revision)
    path  = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( revision ) )
    files = @file_wrapper.directory_listing( FilePathUtils.escape_glob_brackets( path ) ).sort.reject { |entry| @file_wrapper.directory?( entry ) }

    return through_real_base( files.map { |file| File.expand_path( file ) }, path )
  end

  # `paths`, found below the base of `pattern`, respelled below the base's real path
  def through_real_base(paths, pattern)
    base = File.expand_path( FilePathUtils.no_decorators( pattern ) )
    real = File.expand_path( ProjectPaths.canonical( base ) )
    return paths if base == real

    return paths.map { |path| path == base || path.start_with?( "#{base}/" ) ? real + path[base.length..] : path }
  end
end
