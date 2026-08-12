# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Includes
  # Class method to convert mixed list of Include objects into an order-preserving list of hashes
  #
  # @param includes [Array<Include>] List of UserInclude and SystemInclude objects
  # @return [Array<Hash>] Array of hashes, each with 'type' and 'filepath' keys
  # @example
  #   includes = [
  #     UserInclude.new("header.h"),
  #     SystemInclude.new("stdio.h"),
  #     UserInclude.new("module.h")
  #   ]
  #   Include.to_hash(includes)
  #   # => [
  #   #   { 'type' => 'user', 'filepath' => 'header.h' },
  #   #   { 'type' => 'system', 'filepath' => 'stdio.h' },
  #   #   { 'type' => 'user', 'filepath' => 'module.h' }
  #   # ]
  def self.to_hashes(includes)
    return includes.map do |include|
      type = 
        case include
        when MockInclude then 'mock'
        when UserInclude then 'user'
        when SystemInclude then 'system'
        else raise ArgumentError, "Unknown Include type: #{include.class}"
        end

      hash = {
        'type' => type,
        'filepath' => include.filepath,
      }
      # `include_path` is only ever meaningful on a reconciled SystemInclude, so it's
      # written only when actually set -- a cached build's YAML stays uncluttered for
      # the common, plain case.
      hash['include_path'] = include.include_path if include.include_path
      hash
    end
  end

  # Class method to convert a list of hashes back into Include objects
  #
  # @param hashes [Array<Hash>] Array of hashes with 'type' and 'filepath' keys
  # @return [Array<Include>] List of UserInclude and SystemInclude objects
  # @raise [ArgumentError] If hash is missing required keys or has invalid type
  # @example
  #   hashes = [
  #     { 'type' => 'user', 'filepath' => 'header.h' },
  #     { 'type' => 'system', 'filepath' => 'stdio.h' },
  #     { 'type' => 'user', 'filepath' => 'module.h' }
  #   ]
  #   Include.from_hashes(hashes)
  #   # => [
  #   #   UserInclude.new("header.h"),
  #   #   SystemInclude.new("stdio.h"),
  #   #   UserInclude.new("module.h")
  #   # ]
  def self.from_hashes(hashes)
    return hashes.map do |hash|
      raise ArgumentError, "Hash missing 'type' key" unless hash.key?('type')
      raise ArgumentError, "Hash missing 'filepath' key" unless hash.key?('filepath')
      
      case hash['type']
      when 'user'
        UserInclude.new(hash['filepath'], include_path: hash['include_path'])
      when 'mock'
        MockInclude.new(hash['filepath'])
      when 'system'
        SystemInclude.new(hash['filepath'], include_path: hash['include_path'])
      else
        raise ArgumentError, "Invalid include type: #{hash['type']}. Must be 'user' or 'system'"
      end
    end
  end

  # Class method to extract all matching includes by filename pattern
  def self.filter(includes, pattern)
    includes.select { |include| include.filename =~ pattern }
  end

  # Class method to extract all system includes
  def self.system(includes)
    includes.select { |include| include.is_a?(SystemInclude) }
  end

  # Class method to extract all user includes
  def self.user(includes)
    includes.select { |include| include.is_a?(UserInclude) }
  end

  # Class method to check for a filename in the collection
  def self.contains?(includes, filename)
    includes.any? { |include| include.filename == filename }
  end

  # Class method for non-mutating sanitize
  #
  # @param includes [Array<Include>] List of includes to sanitize
  # @param block [Proc] Optional block passed to reject! for custom filtering
  # @yield [include] Each include object for custom rejection logic
  # @return [Array<Include>] New sanitized list
  # @example Basic usage
  #   Includes.sanitize(includes)
  # @example Custom rejection
  #   Includes.sanitize(includes) { |include, all| ... }
  def self.sanitize(includes, &block)
    _includes = includes.clone
    self.sanitize!(_includes, &block)
    return _includes
  end

  # Class method for mutating sanitize
  #
  # @param includes [Array<Include>] List of includes to sanitize in place
  # @param block [Proc] Optional block passed to reject! for custom filtering
  # @yield [include] Each include object for custom rejection logic
  # @return [Array<Include>] The modified includes list
  # @example Basic usage
  #   Includes.sanitize!(includes)
  # @example Custom rejection
  #   Includes.sanitize!(includes) { |include, all| ... }
  def self.sanitize!(includes, &block)
    # Remove any duplicates
    includes.uniq!

    # Apply custom rejection with access to full list if block provided
    if block_given?
      includes.reject! { |include| block.call(include, includes) }
    end

    # Ensure system includes come first
    self.sort!(includes)

    return includes
  end

  # Class method to reconcile bare, user, and system includes returning a list of
  # reconciled user and system includes.
  #
  # Purpose
  # -------
  # Bare include preprocessing extracts user and system includes, but there's no way
  # to explicitly differentiate these. Meanwhile, by necessity, user and system include 
  # extraction can identify too many includes. This class method uses the knowledeg of
  # the different types of extraction to reconcile the two lists. It accomplishes:
  #  1. Paring down system includes to the include directives used in original file.
  #  2. Paring down user includes to the include directives used in original file.
  #  3. Reconciling a list of user & system includes properly distinguished.
  #
  # Method
  # ------
  # Compares bare includes against user and system includes and applies the following rules:
  # 1. Intersection of bare includes and system includes.
  # 2. Intersection of bare includes and user includes.
  #
  # A matched system include's `filepath` is its real, resolved location (possibly
  # absolute), which is what identity and deduplication need but is wrong to render
  # verbatim into a generated file. Each matched system include is therefore rebuilt
  # carrying `include_path:` recovered from `bare` -- the original, as-written directive
  # text -- via `best_bare_match`, so `<sys/stat.h>` renders as written instead of
  # collapsing to `<stat.h>`. User includes are left untouched; unlike a system header's
  # `<...>` text, a quoted include's own bare-includes pass can be resolved by GCC's
  # directory-relative search before reconciliation ever sees it, so `bare` isn't a
  # reliable source of "the literal, as-written spelling" for a user include.
  def self.reconcile(bare:, user:, system:)
    # Validate input types

    # `bare` can only be base Include objects, no sub-classes.
    unless bare.is_a?(Array) && bare.all? { |include| include.class == Include }
      raise ArgumentError, "`bare` must be an Array of Include objects"
    end

    # Ensure `user` is an array of UserInclude objects or sub-classes
    unless user.is_a?(Array) && user.all? { |include| include.is_a?(UserInclude) }    
      raise ArgumentError, "`user` must be an Array of UserInclude objects"
    end
    
    # Ensure `system` is an array of SystemInclude objects or sub-classes
    unless system.is_a?(Array) && system.all? { |include| include.is_a?(SystemInclude) }    
      raise ArgumentError, "`system` must be an Array of SystemInclude objects"
    end

    return [] if bare.empty?

    system_includes = []
    user_includes = []

    # Create set of bare include filenames for O(1) lookup
    bare_filenames = Set.new(bare.map(&:filename))

    # Intersect system includes with bare includes based on filename, then rebuild each
    # matched system include carrying the original, as-written directive spelling
    # recovered from bare via best_bare_match, since filepath alone (the real, resolved
    # location) is wrong to render verbatim.
    system_includes = system.select do |include|
      bare_filenames.include?(include.filename)
    end.map do |include|
      original = best_bare_match(bare, include.filepath)
      SystemInclude.new(include.filepath, include_path: original.filepath)
    end

    # Intersect user includes with bare includes based on filename.
    # Keep user includes (including subclasses) that have matching filenames in bare list.
    user_includes = user.select do |include|
      bare_filenames.include?(include.filename)
    end    

    # Construct reconciled list of includes with reconciled results.
    # Always system includes first (C best practice).
    return (system_includes + user_includes)
  end

  # Two filepaths correspond if the shorter one's path segments equal the longer one's
  # own trailing segments, exactly, in order -- checked without regard for which side is
  # shorter, since either a bare entry or its candidate may be the one carrying less path.
  def self.paths_correspond?(a, b)
    segments_a = a.split(/[\\\/]/).reject(&:empty?)
    segments_b = b.split(/[\\\/]/).reject(&:empty?)
    shorter, longer = segments_a.length <= segments_b.length ? [segments_a, segments_b] : [segments_b, segments_a]
    return longer.last(shorter.length) == shorter
  end
  private_class_method :paths_correspond?

  # Finds the bare entry that best identifies a resolved system include's original,
  # as-written spelling. A bare entry carries no information about whether its own
  # #include was quoted or bracketed, so a project's own same-named quoted include
  # (`#include "stat.h"`) can sit in `bare` right alongside a system one
  # (`#include <sys/stat.h>`). Preferring the *longest* path correspondence, rather than
  # merely the first one found, keeps a short, unrelated bare entry -- which trivially
  # "corresponds" to any longer resolved path ending in the same filename -- from
  # shadowing the correct, more specific entry. Falls back to the longest same-filename
  # candidate, even without path correspondence, only when the compiler's real
  # search-path structure doesn't literally match the directive's own spelling (a
  # symlinked or vendored include root, for instance).
  def self.best_bare_match(bare, filepath)
    candidates = bare.select { |bare_include| bare_include.filename == File.basename(filepath) }
    corresponding = candidates.select { |bare_include| paths_correspond?(bare_include.filepath, filepath) }
    pool = corresponding.empty? ? candidates : corresponding
    return pool.max_by { |bare_include| bare_include.filepath.split(/[\\\/]/).reject(&:empty?).length }
  end
  private_class_method :best_bare_match

  # Sort list so system includes are at the beginning
  # (Best practice)
  def self.sort(includes)
    _includes = includes.clone
    self.sort!(_includes)
    return _includes
  end

  def self.sort!(includes)
    includes.sort_by! { |include| include.is_a?(SystemInclude) ? 0 : 1 }
    return includes
  end
end


# Base class for C header includes
class Include
  attr_reader :filepath
  attr_reader :filename
  attr_reader :path
  attr_reader :include_path

  # Initialize an Include object from a C include statement or simple filepath.
  #
  # @param statement [String] A C include statement. Examples:
  #  - #include "header.h"
  #  - #include <stdio.h>
  #  - A quoted/bracketed filepath (e.g., '"header.h"' or <stdio.h>')
  #  - A plain filepath (e.g., 'path/to/header.h')
  # @param include_path [String, nil] (default: nil)
  #  - When set, this exact spelling is used in the include directive, taking
  #    precedence over `filepath`/`filename`. This exists for a reconciled
  #    SystemInclude, whose `filepath` is deliberately the header's real, resolved
  #    location (needed elsewhere for identity -- see `Includes.sanitize!`) rather than
  #    the original, as-written directive text a reconciled render needs.
  # @raise [ArgumentError] If the statement is empty or becomes empty after cleaning
  def initialize(statement, include_path: nil)
    @filepath = clean(statement)

    raise ArgumentError, "Empty include statement" if @filepath.empty?

    @filename = File.basename(@filepath)
    @path = File.dirname(@filepath)
    @include_path = clean(include_path) if include_path
  end

  # Method specialized by subclasses
  def to_s()
    # Simple string representation of class contents with no additional formatting or #include decoration
    return @filename
  end

  def to_str()
    # Coerce to string for implicit conversions (e.g., string interpolation, concatenation)
    # For instance, Rake#FileList needs this to treat Include objects as strings when extending with #pathmap
    return @filename
  end

  # Equality operator -- for Include objects and strings
  def ==(other)
    case other
    when String
      include == other
    when UserInclude, MockInclude
      if self.is_a?(SystemInclude)
        false
      else
        include == other.include
      end
    when SystemInclude
      if self.is_a?(UserInclude)
        false
      else
        include == other.include
      end
    when Include
      include == other.include
    else
      false
    end
  end

  # Matching operator for pattern matching on filename
  def =~(pattern)
    @filename =~ pattern
  end

  # Not matching operator for pattern matching on filename
  def !~(pattern)
    @filename !~ pattern
  end

  # Hash method for use in sets and as hash keys
  def hash()
    include.hash
  end

  # Alias for == to support case equality
  alias eql? ==

  # Returns the configured entry to use in the include directive
  def include()
    return @include_path if @include_path
    @filename
  end

  private

  def clean(line)
    # Remove any initial `#include` statement
    _line = line.gsub(/#\s*include/, '')
    
    # Remove any quotation marks from an extracted user include directive
    _line.gsub!(/"/, '')
    
    # Remove any angle brackets from an extracted system include directive
    _line.gsub!(/</, '')
    _line.gsub!(/>/, '')
    
    # Whitespace cleanup
    _line.strip!

    return _line
  end
end

# UserInclude generates #include "header.h" (with quotes)
class UserInclude < Include
  def to_s()
    "#include \"#{include}\""
  end
end

# MockInclude generates #include "<subdir>/header.h" (with quotes)
# Specialization to support include directive paths for mocks before path are supported everywhere
class MockInclude < UserInclude
  def to_s()
    "#include \"#{filepath}\""
  end
end


# SystemInclude generates #include <header.h> (with brackets)
class SystemInclude < Include
  def to_s()
    "#include <#{include}>"
  end
end
