# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Resolves the ordered list of .rake files Ceedling will load for a given project
# configuration. Callable from both bin/ (early, before do_setup) and lib/ (within
# ConfiguratorPlugins). Config must be in structured (pre-flatten) format.
module RakefileComponentResolver
  module_function

  RAKEFILES_DIR = 'rakefiles' unless const_defined?(:RAKEFILES_DIR, false)

  # Every .rake file in lib/ceedling/rakefiles/<subdir>, sorted for deterministic,
  # platform-independent ordering -- stock/release Rakefiles are discovered by role
  # subdirectory rather than named individually, so adding or removing one there
  # never requires updating a list anywhere else.
  def gather_rakefiles(ceedling_lib_path, subdir)
    Dir.glob( File.join(ceedling_lib_path, RAKEFILES_DIR, subdir, '*.rake') ).sort
  end

  def base_rakefiles(ceedling_lib_path)
    gather_rakefiles(ceedling_lib_path, 'base')
  end

  def test_rakefiles(ceedling_lib_path)
    gather_rakefiles(ceedling_lib_path, 'tests')
  end

  def release_rakefiles(ceedling_lib_path)
    gather_rakefiles(ceedling_lib_path, 'release')
  end

  # Returns ordered plugin search paths: user-configured paths first, built-in Ceedling
  # plugins path last. This ordering lets user plugins shadow built-in plugins of the
  # same name. Used by both resolve() (bin/ CLI scope) and Configurator#prepare_plugins_load_paths
  # (application scope) so both scopes search plugins in the same priority order.
  def prepare_plugin_load_paths(config, ceedling_plugins_path)
    load_paths = Array( config.dig(:plugins, :load_paths) ).dup
    load_paths << ceedling_plugins_path
    load_paths.compact!
    load_paths.uniq!
    load_paths
  end

  # Returns ordered list of all .rake file paths for the given config:
  #   - Stock files (always)
  #   - Conditional stock files (rules_release, tasks_release if release_build is enabled)
  #   - Plugin .rake files (first matching <root>/<plugin>/<plugin>.rake across load_paths)
  def resolve(config, ceedling_lib_path, ceedling_plugins_path)
    paths = base_rakefiles(ceedling_lib_path) + test_rakefiles(ceedling_lib_path)

    if config.dig(:project, :release_build)
      paths.concat( release_rakefiles(ceedling_lib_path) )
    end

    paths.concat(
      plugin_rake_files( config, prepare_plugin_load_paths(config, ceedling_plugins_path) )
    )

    return paths
  end

  # Returns ordered list of .rake file paths for enabled plugins only.
  # Searches each root in load_paths for <root>/<plugin>/<plugin>.rake.
  # Uses File.exist? directly (no DI needed) — same check as ConfiguratorPlugins#find_rake_plugins.
  # Array() wraps nil gracefully so missing config keys don't raise.
  def plugin_rake_files(config, load_paths)
    enabled = Array( config.dig(:plugins, :enabled) )
    results = []

    enabled.each do |plugin|
      load_paths.each do |load_path|
        candidate = File.join(load_path, plugin, "#{plugin}.rake")
        if File.exist?(candidate)
          results << candidate
          break
        end
      end
    end

    results
  end

end
