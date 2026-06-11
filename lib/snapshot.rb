# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# snapshot.rb <config-file> <snapshot-dir>
#
# Copies versioned project files into <snapshot-dir> so that the mkdocs documentation
# build can reference them with relative paths that are correct for each deployed version.
#
# <config-file>  Path to the YAML snapshot configuration file. Lists source files to copy
#                as paths relative to the project root.
# <snapshot-dir> Destination directory. Each file is written to <snapshot-dir>/<relative-path>,
#                preserving directory structure.
#
# Invoked via `rake docs:snapshot` (or automatically by `rake docs:build`).
# 
# This script assumes the destination directory does not exist.

require 'fileutils'
require 'yaml'

PROJECT_ROOT    = File.expand_path('..', __dir__)
SNAPSHOT_CONFIG = ARGV[0] or abort("Usage: snapshot.rb <config-file> <snapshot-dir>")
SNAPSHOT_DIR    = ARGV[1] or abort("Usage: snapshot.rb <config-file> <snapshot-dir>")

config = YAML.load_file(SNAPSHOT_CONFIG)
files  = config.fetch('files')

files.each do |relative_path|
  src  = File.join(PROJECT_ROOT, relative_path)
  dest = File.join(SNAPSHOT_DIR, relative_path)

  # Create the destnation directory
  FileUtils.mkdir_p(File.dirname(dest))
  # Copy the path, including recursive copying for directories
  FileUtils.cp_r(src, dest)
  puts "  snapshot: #{relative_path}"
end

puts "Snapshot complete — #{files.length} file(s) written to #{SNAPSHOT_DIR}"
