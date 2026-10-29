# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/file_path_utils'
require 'ceedling/project_paths'

# What a build root may be, and what in it a build may collect. Clobber empties the
# directories Ceedling creates in the build root, so the build root names a directory,
# neither the project directory nor one above it. Collection leaves out the directories
# Ceedling creates, and a :paths or :files entry within the build root is warned of.
module BuildRootPolicy

  # The settings naming the directories Ceedling creates, in the build root or, for mocks,
  # wherever the mock path places them
  CREATED = %i[
    project_build_artifacts_root project_build_tests_root project_build_release_root project_build_vendor_root
    project_build_dependencies_cache_path project_log_path cmock_mock_path
  ].freeze

  # Why `root` is no build root, or nil when it is one. Compared as the places really are,
  # so no symlinked spelling of the project gets by.
  def self.problem(root)
    return 'names no directory' if root.strip.empty?
    return 'is the project directory or holds it' if ProjectPaths.contains?( ProjectPaths.canonical( root ), ProjectPaths.working_dir )

    return nil
  end

  # The message refusing `root` for `problem`
  def self.message(root, problem)
    return ":project ↳ :build_root => '#{root}' #{problem}. Give the build its own directory, such as 'build'."
  end

  # Each :paths and :files entry that adds to a build from within `root`, as
  # [section, key, entry]
  def self.entries_within(root, config)
    real = ProjectPaths.canonical( root )
    return additive_entries( config ).select { |_, _, entry| ProjectPaths.contains?( real, ProjectPaths.canonical( FilePathUtils.no_decorators( entry ) ) ) }
  end

  # A warning of each :paths and :files entry that adds to a build from within `root`, its
  # place in the configuration spelled by the block
  def self.warnings(root, config)
    return entries_within( root, config ).map do |section, key, entry|
      "#{yield( [section, key] )} => '#{entry}' lies in the build root '#{root}'. Ceedling leaves out the directories it creates there."
    end
  end

  # The directories Ceedling creates, each enabled plugin's build directory among them, from
  # a flattened configuration. A setting with no path names none.
  def self.reserved(config)
    root    = config[:project_build_root].to_s
    plugins = root.empty? ? [] : (config[:plugins_enabled] || []).map { |plugin| File.join( root, File.basename( plugin.to_s ) ) }
    return (CREATED.map { |key| config[key].to_s } + plugins).reject( &:empty? ).uniq
  end

  # Every :paths and :files entry that adds to a build, as [section, key, entry]
  def self.additive_entries(config)
    entries = [:paths, :files].flat_map do |section|
      (config[section] || {}).flat_map { |key, list| Array( list ).flatten.map { |entry| [section, key, entry] } }
    end
    return entries.select { |_, _, entry| entry.is_a?( String ) and FilePathUtils.add_path?( entry ) }
  end
  private_class_method :additive_entries

end
