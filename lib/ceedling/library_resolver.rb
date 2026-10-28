# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Finds the library files a link's :libraries entries name, so a link can depend on their
# contents. Which file a toolchain links is its own choice, so every candidate that exists
# is found. A library only the toolchain's own search paths hold is not found, and a link
# never depends on a file that doesn't exist, which would read as changed on every build.
class LibraryResolver

  # Library extensions toolchains search for beyond a project's own :extension ↳ :libraries
  TOOLCHAIN_EXTENSIONS = ['.a', '.so', '.dylib', '.tbd', '.dll.a', '.lib'].freeze

  constructor :file_wrapper, :file_path_collection_utils

  # entries:      :libraries entries, each a bare name, an `-l:` filename, or a path
  # search_paths: :paths ↳ :libraries, decorated and globbed as configured
  # files:        library files known exactly, as a plugin knows those it builds
  def resolve(entries:, search_paths:, files: [])
    directories = @file_path_collection_utils.collect_paths( search_paths )

    candidates = Array( entries ).flatten.compact.flat_map { |entry| candidates_for( entry.to_s, directories ) }
    candidates += Array( files )

    found = candidates.map { |path| @file_path_collection_utils.shortest_path_from_working( File.expand_path( path ) ) }
    return found.select { |path| library_file?( path ) }.uniq
  end

  # The library files a link with these :libraries entries depends on: those the entries
  # resolve to on :paths ↳ :libraries, and those plugins publish in LIBRARIES_LINK_FILES
  def link_files(entries)
    return resolve(
      entries:      entries,
      search_paths: ((defined? PATHS_LIBRARIES) ? PATHS_LIBRARIES : nil) || [],
      files:        ((defined? LIBRARIES_LINK_FILES) ? LIBRARIES_LINK_FILES : nil) || []
    )
  end

  private

  # An `-l:` entry names its exact filename, a path names itself, and a bare name names every
  # library filename a toolchain makes of it
  def candidates_for(entry, directories)
    return within( directories, entry.delete_prefix( ':' ) ) if entry.start_with?( ':' )
    return [entry] if absolute?( entry )
    return [entry] + within( directories, entry ) if path?( entry )

    return within( directories, *library_filenames( entry ) )
  end

  def within(directories, *names)
    return directories.product( names ).map { |directory, name| File.join( directory, name ) }
  end

  def library_filenames(name)
    return ["lib#{name}", name].product( extensions ).map( &:join )
  end

  # A path, or a filename with a library extension, rather than a name the linker expands
  def path?(entry)
    return entry.match?( %r{[/\\]} ) || extensions.any? { |extension| entry.end_with?( extension ) }
  end

  def absolute?(entry)
    return File.expand_path( entry ) == entry || entry.match?( %r{\A[A-Za-z]:[/\\]} )
  end

  def extensions
    @extensions ||= ((defined?( EXTENSION_LIBRARIES ) ? EXTENSION_LIBRARIES.to_a : []) + TOOLCHAIN_EXTENSIONS).uniq
  end

  def library_file?(path)
    return @file_wrapper.exist?( path ) && !@file_wrapper.directory?( path )
  end

end
