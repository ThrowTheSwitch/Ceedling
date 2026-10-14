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

  def initialize(config)
    @config = config
  end

  # Whether any test defines the symbol, with or without a value. Test defines are a
  # list, or a hash of per-test matchers whose values are lists.
  def test_defined?(symbol)
    return strings( @config[:defines_test] ).any? { |entry| entry.split( '=', 2 ).first.strip == symbol }
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

  def strings(value)
    case value
    when Hash   then value.values.flat_map { |entry| strings( entry ) }
    when Array  then value.flat_map { |entry| strings( entry ) }
    when String then [value]
    else []
    end
  end

end
