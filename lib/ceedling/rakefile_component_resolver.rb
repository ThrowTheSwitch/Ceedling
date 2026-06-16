# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Resolves the ordered list of .rake files Ceedling will load for a given project
# configuration. Callable from both bin/ (early, before do_setup) and lib/ (within
# ConfiguratorPlugins). Config must be in structured (pre-flatten) format.
module RakefileComponentResolver
  module_function

  STOCK_RAKE_FILES = %w[
    tasks_base.rake
    tasks_filesystem.rake
    tasks_tests.rake
    rules_tests.rake
  ].freeze

  RELEASE_RAKE_FILES = %w[
    rules_release.rake
    tasks_release.rake
  ].freeze

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
    paths = STOCK_RAKE_FILES.map { |f| File.join(ceedling_lib_path, f) }

    if config.dig(:project, :release_build)
      RELEASE_RAKE_FILES.each { |f| paths << File.join(ceedling_lib_path, f) }
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
