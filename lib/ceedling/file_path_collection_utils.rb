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

  # The directories one or more (+:/-:) paths and globs name, each spelled canonically, once.
  # A `-:` entry, and each path in `exclude`, drops the directories it names and every
  # directory below them, except one an additive entry names nearer to it.
  def collect_paths(paths, exclude: [])
    # Nil input (e.g. unconfigured section) is treated as an empty list
    return [] if paths.nil?

    additive, subtractive = paths.partition { |entry| FilePathUtils.add_path?( entry ) }

    kept = spelled_directories( additive ).select( &kept_by( additive, subtractive, exclude ) )
    return kept.map { |_dir, real| ProjectPaths.relative( real ) }.uniq
  end

  # Given a file list, add to it or remove from it considering (+:/-:) aggregation operators.
  # Rake's FileList does not robustly handle relative filepaths and patterns.
  # So, we rebuild the FileList ourselves and return it.
  def revise_filelist(list, revisions)
    # Nil list produces an empty FileList; nil revisions leaves the list unchanged
    return FileList.new([]) if list.nil?

    additive, subtractive = (revisions || []).partition { |revision| FilePathUtils.add_path?( revision ) }
    minus = left_out( subtractive )
    kept  = listed_and_added( list, additive ).reject { |path| minus.include?( key( path ) ) }

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

  # Whether a directory lies nearer to an additive entry than to anything left out
  def kept_by(additive, subtractive, exclude)
    bases = spellings( additive.map { |entry| FilePathUtils.no_decorators( entry ) } )
    minus = spellings( directories_of( subtractive ) + exclude )
    return ->(spelled) { nearer( spelled, bases ) < nearer( spelled, minus ) }
  end

  # The files `-:` revisions name, compared as `key` spells them
  def left_out(subtractive)
    return Set.new( files_of( subtractive ).map { |path| key( path ) } )
  end

  # A file list's files and those additive revisions name, once each
  def listed_and_added(list, additive)
    return (list.map { |path| file_spelling( path ) } + files_of( additive )).uniq { |path| key( path ) }
  end

  def directories_of(entries)
    return entries.flat_map { |entry| entry_directories( entry ) }
  end

  # Every directory `entries` name, once, by its as-listed and its real spelling
  def spelled_directories(entries)
    return directories_of( entries ).uniq.map { |dir| [dir, ProjectPaths.real_absolute( dir )] }
  end

  def files_of(revisions)
    return revisions.flat_map { |revision| revision_files( revision ) }
  end

  # Every directory one entry names, absolute as listed
  def entry_directories(entry)
    path = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( entry ) )
    dirs = listed_directories( path )
    dirs = with_parents( dirs, path ) if path.end_with?( '/**', '/*' )

    return dirs.map { |dir| ProjectPaths.absolute( dir ) }
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

  # Every file one :files revision names, each spelled through its directory as it really
  # is. #104 -- a literal `[`/`]` is escaped as in `listed_directories`.
  def revision_files(revision)
    path  = ProjectPaths.standardize( FilePathUtils.no_aggregation_decorators( revision ) )
    files = @file_wrapper.directory_listing( FilePathUtils.escape_glob_brackets( path ) ).sort.reject { |entry| @file_wrapper.directory?( entry ) }

    return files.map { |file| file_spelling( file ) }
  end

  # A file's absolute path through its directory as it really is, keeping its own name
  def file_spelling(file)
    return File.join( ProjectPaths.real_absolute( File.dirname( file ) ), File.basename( file ) )
  end

  # Both the as-listed and the real spelling of each of `paths`, so either reaches it
  def spellings(paths)
    return Set.new( paths.flat_map { |path| [ProjectPaths.absolute( path ), ProjectPaths.real_absolute( path )] }.map { |path| key( path ) } )
  end

  # How many directories above a directory, by either of its two spellings, the nearest one
  # in `spelled` lies: 0 for the directory itself, or infinity for none
  def nearer(spellings, spelled)
    return spellings.map { |path| distance( path, spelled ) }.min
  end

  def distance(path, spelled)
    steps = 0
    loop do
      return steps if spelled.include?( key( path ) )

      parent = File.dirname( path )
      return Float::INFINITY if parent == path

      path   = parent
      steps += 1
    end
  end

  # Windows compares paths without regard to case
  def key(path)
    return ProjectPaths::WINDOWS ? path.downcase : path
  end
end
