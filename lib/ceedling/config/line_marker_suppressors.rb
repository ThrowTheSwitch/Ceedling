# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Finds the preprocessor options that suppress line markers wherever configuration hands
# them to test preprocessing. Test preprocessing reads line markers to find a file's
# #includes, its mockable functions, and its test cases. A preprocessor given either
# option still succeeds, so nothing later would report the problem. Each finding is a
# pair: the configuration keys leading to the entry, and the entry itself.
class LineMarkerSuppressors

  OPTIONS = ['-P', '--no-line-commands'].freeze

  # Flag operations that reach the preprocessor. Test preprocessing uses :compile flags
  # wherever no :preprocess flags apply.
  OPERATIONS = [:preprocess, :compile].freeze

  # Preprocessor tools whose output is read through its line markers. A bare-includes
  # make rule has none to lose.
  TOOLS = [:test_file_full_preprocessor, :test_file_directives_only_preprocessor].freeze

  # Only lists and matcher lists are read, never matcher keys. A malformed section is
  # validate_flags' to report.
  def self.in_flags(flags, contexts)
    return contexts.product( OPERATIONS ).flat_map do |context, operation|
      in_entries( [:flags, context, operation], value_at( flags, [context, operation] ) )
    end
  end

  # A :tools_<name> shortcut's arguments are merged into its tool, but the shortcut is
  # where they were written
  def self.in_tools(config)
    return TOOLS.flat_map do |name|
      shortcut = Array( value_at( config, [:"tools_#{name}", :arguments] ) )
      suppressing( Array( value_at( config, [:tools, name, :arguments] ) ) ).map do |entry|
        [shortcut.include?( entry ) ? [:"tools_#{name}", :arguments] : [:tools, name, :arguments], entry]
      end
    end
  end

  def self.in_entries(walk_keys, entries)
    return suppressing( entries ).map { |entry| [walk_keys, entry] } if entries.is_a?( Array )
    return [] unless entries.is_a?( Hash )

    return entries.flat_map { |matcher, list| list.is_a?( Array ) ? in_entries( walk_keys + [matcher], list ) : [] }
  end

  def self.suppressing(entries)
    return entries.flatten.grep( String ).select { |entry| suppresses?( entry ) }
  end

  # An entry may hold several options, and -Wp, hands the preprocessor a comma-separated list
  def self.suppresses?(entry)
    tokens = entry.split.flat_map { |token| token.start_with?( '-Wp,' ) ? token.split( ',' ).drop( 1 ) : [token] }
    return !(tokens & OPTIONS).empty?
  end

  def self.value_at(hash, keys)
    return keys.reduce( hash ) { |value, key| value.is_a?( Hash ) ? value[key] : nil }
  end

  private_class_method :in_entries, :suppressing, :suppresses?, :value_at

end
