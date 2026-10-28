# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_path_utils'
require 'ceedling/project_paths'

# What a build root may be. Clobber empties the build root's test and release trees, so it
# holds none of the project's own files: it names a directory, neither the project
# directory nor one above it, holding no base of a :paths or :files entry that adds to a
# build.
module BuildRootPolicy

  # Why `root` is no build root for `config`, or nil when it is one
  def self.problem(root, config)
    return 'names no directory' if root.strip.empty?
    return 'is the project directory or holds it' if ProjectPaths.contains?( root, ProjectPaths.working_dir )

    held = additive_entries( config ).find { |entry| ProjectPaths.contains?( root, FilePathUtils.no_decorators( entry ) ) }
    return "holds '#{held}', which adds to a build" unless held.nil?

    return nil
  end

  # Every :paths and :files entry that adds to a build
  def self.additive_entries(config)
    entries = [:paths, :files].flat_map { |section| (config[section] || {}).values.flatten }
    return entries.select { |entry| entry.is_a?( String ) and FilePathUtils.add_path?( entry ) }
  end
  private_class_method :additive_entries

end
