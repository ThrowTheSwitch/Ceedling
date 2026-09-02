# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_path_utils'

# A configured filename-extension setting for one file type (source, header,
# assembly, and so on). A project may name a file type with a single
# extension or with several -- an assembly file might be `.s` or `.S`, for
# instance -- so this wraps that setting uniformly as an ordered collection,
# whether the project configuration supplied one string or a list of them.
# Order matters: the first entry is the type's canonical extension, used
# whenever a filename must be generated rather than searched for.
class FilenameExtension

  include Enumerable

  def initialize(value)
    # Kernel#Array() leaves an Array as it is and wraps anything else (a bare
    # String) in a single-element Array, so callers never have to know or
    # care which form a given project configuration used.
    @extensions = Array(value)
  end

  def each(&block)
    @extensions.each(&block)
  end

  # Whether this file type was configured with no extensions at all -- a project can
  # disable a file type this way (an empty :assembly list, say, meaning the project
  # has no assembly files), which some callers need to check before doing anything
  # extension-dependent at all.
  def empty?
    @extensions.empty?
  end

  # The extension used to generate a new filename of this type. A file type
  # can be searched for under any of its extensions, but generated output
  # needs one definite answer -- the first-listed extension is that answer.
  def primary
    @extensions.first
  end

  # Whether `filepath` already carries one of this type's extensions --
  # the question asked when classifying an existing file (is this a source
  # file? an assembly file?) rather than when producing a new one.
  def match?(filepath)
    @extensions.include?(File.extname(filepath))
  end

  # Every filename `basename` could take on under this type, one per
  # configured extension. Used to search a directory for a file of this
  # type when its extension isn't known in advance -- a build input file
  # named `foo` might be sitting on disk as `foo.s` or `foo.S`.
  def candidates(basename)
    @extensions.map { |ext| basename.ext(ext) }
  end

  # Wildcard glob fragments for every configured extension, for building
  # a `path/*ext` search pattern per extension when collecting whole file
  # lists rather than resolving one specific candidate filename.
  #
  # #104 -- `path` here is an already-resolved, concrete directory (the output of
  # FilePathCollectionUtils#collect_paths, not a user-typed glob), but every caller
  # hands the result straight to Rake::FileList#include, which globs it again --
  # so a literal `[`/`]` surviving from the real directory name (collect_paths'
  # own fix escapes brackets only for *its own* glob, not this next one) still
  # needs escaping here, or the file list silently comes up empty for that path.
  # FilePathUtils.glob handles the escaping itself.
  def glob_patterns(path)
    @extensions.map { |ext| FilePathUtils.glob(path, "*#{ext}") }
  end

  # A human-readable rendering of the configured extensions for log and
  # error messages, e.g. describing what was searched for and not found.
  def to_s
    @extensions.join(' or ')
  end

end
