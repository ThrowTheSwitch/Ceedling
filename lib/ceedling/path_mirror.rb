# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_path_utils'

# Answers the question build output asks when it wants to avoid same-basename
# collisions: given a resolved file and the raw (still possibly glob/decorator-laden)
# `:paths` entries a project configured for that file's category, what subdirectory
# should this file's build artifact live in so its place in the source tree survives
# into the build tree? A file directly inside a configured root needs no
# subdirectory at all; a file nested beneath one carries that nesting forward.
class PathMirror

  # The directory portion of `filepath` below whichever `roots` entry is its
  # longest (most specific) matching ancestor, or '' if no root contains it at all
  # -- the safe fallback that leaves such a file's build placement flat.
  def self.relative_subdir(filepath, roots)
    relative_subdir_from_clean_roots(filepath, clean_roots(roots))
  end

  # Strips decorators and glob specifiers from each entry in `roots`, dropping any that
  # end up empty. A caller mirroring many files against the same `roots` list -- a whole
  # build's worth of sources against one project's configured paths, say -- can compute
  # this once and feed the result to `relative_subdir_from_clean_roots` for every file,
  # rather than every file's own call re-parsing the same still-decorated list from scratch.
  def self.clean_roots(roots)
    roots
      .map { |root| FilePathUtils.no_decorators(root) }
      .reject(&:empty?)
  end

  # As `relative_subdir`, but takes roots already reduced by `clean_roots` instead of
  # raw, possibly glob/decorator-laden `:paths` entries.
  def self.relative_subdir_from_clean_roots(filepath, clean_roots)
    file_dir = File.dirname(filepath)

    matching_roots = clean_roots.select do |root|
      file_dir == root || file_dir.start_with?(root + '/')
    end

    return '' if matching_roots.empty?

    best_root = matching_roots.max_by(&:length)
    return '' if file_dir == best_root

    file_dir[(best_root.length + 1)..]
  end

end
