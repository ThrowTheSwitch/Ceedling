# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'pathname'

# What the project configuration says about files and defines the Module Generator is
# about to create or depend on. Its answers become warnings, never refusals.
class ModuleGeneratorProject

  COLLECTIONS = %i[collection_all_source collection_all_headers collection_all_tests].freeze

  # `test_defines` returns the defines a build gives a test file, resolving per-test
  # matchers against that file's path exactly as a test build does
  def initialize(config, test_defines:)
    @config       = config
    @test_defines = test_defines
  end

  # Whether a build of the test file defines the symbol, with or without a value
  def test_defined?(symbol, test_path)
    return @test_defines.call( test_path ).any? { |entry| entry.to_s.split( '=', 2 ).first.strip == symbol }
  end

  # Existing project files elsewhere that share a planned file's name, keyed by the
  # planned path. A planned file that already exists is not its own duplicate.
  def same_named(planned)
    existing = COLLECTIONS.flat_map { |key| @config[key] || [] }

    return planned.each_with_object( {} ) do |path, found|
      matches = existing.select { |file| same_name_elsewhere?( file, Pathname.new( path ).cleanpath ) }
      found[path] = matches unless matches.empty?
    end
  end

  private

  def same_name_elsewhere?(file, target)
    return File.basename( file ) == target.basename.to_s && Pathname.new( file ).cleanpath != target
  end

end
