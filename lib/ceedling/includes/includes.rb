# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# ========================================================================='

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

      {
        'type' => type,
        'filepath' => include.filepath,
      }
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
        UserInclude.new(hash['filepath'])
      when 'mock'
        MockInclude.new(hash['filepath'])
      when 'system'
        SystemInclude.new(hash['filepath'])
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
    includes.select { |include| include.is_a?(UserInclude) }
  end

  # Class method to extract all user includes
  def self.user(includes)
    includes.select { |include| include.is_a?(SystemInclude) }
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

  # Class method to reconcile bare and system includes returning a list of
  # reconciled user and system includes.
  #
  # Purpose
  # -------
  # Bare include preprocessing extracts user and system includes, but there's no way
  # to explicitly differentiate these. Meanwhile, by necessity, system include 
  # extraction can identify too many system includes. This class method uses this
  # knowledge to reconcile the two lists. It accomplishes:
  #  1. Paring down system includes to the include directives used in original file.
  #  2. Removing system includes from the bare includes list.
  #  3. Recreating a list of user & system includes properly distinguished.
  #
  # Method
  # ------
  # Compares bare includes against user and system includes and applies the following rules:
  # 1. If a system include matches a bare include filename, keep the system include
  #    and remove the matching bare include (system includes take precedence).
  # 2. Remove any system includes that don't match bare include filenames
  # 3. Keep bare includes that have no matching system includes as user includes.
  # 4. If no bare includes exist, return system includes unchanged (should not happen).
  # 5. If no system includes exist, return bare includes unchanged as user includes.
  def self.reconcile(bare:, user:, system:)
    # Validate input types
    unless bare.is_a?(Array) && bare.all? { |include| include.is_a?(Include) }
      raise ArgumentError, "`bare` must be an Array of Include objects"
    end

    return [] if bare.empty?

    unless user.is_a?(Array) && user.all? { |include| include.is_a?(UserInclude) }    
      raise ArgumentError, "`user` must be an Array of UserInclude objects"
    end
    
    unless system.is_a?(Array) && system.all? { |include| include.is_a?(SystemInclude) }    
      raise ArgumentError, "`system` must be an Array of SystemInclude objects"
    end

    system_includes = []
    user_includes = []

    # Create set of bare include filenames for O(1) lookup
    bare_filenames = Set.new(bare.map(&:filename))

    # Intersect system includes with bare includes based on filename.
    # Keep system includes that have matching filenames in bare list.
    system_includes = system.select do |include|
      bare_filenames.include?(include.filename)
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

  # Initialize an Include object from a C include statement or simple filepath.
  #
  # @param statement [String] A C include statement. Examples:
  #  - #include "header.h"
  #  - #include <stdio.h>
  #  - A quoted/bracketed filepath (e.g., '"header.h"' or <stdio.h>')
  #  - A plain filepath (e.g., 'path/to/header.h')
  # @param use_path [Boolean] (default: false)
  #  - If true, use the full filepath in the include directive
  #  - If false, use only the filename
  # @raise [ArgumentError] If the statement is empty or becomes empty after cleaning
  def initialize(statement, use_path: false)
    @filepath = clean(statement)

    raise ArgumentError, "Empty include statement" if @filepath.empty?

    @filename = File.basename(@filepath)
    @path = File.dirname(@filepath)
    @use_path = use_path
  end

  # Method specialized by subclasses
  def to_s()
    # Simple string with no additional formatting or #include decoration
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

  # Hash method for use in sets and as hash keys
  def hash()
    include.hash
  end

  # Alias for == to support case equality
  alias eql? ==

  # Returns the configured entry to use in the include directive
  def include()
    @use_path ? @filepath : @filename
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
# Specialization to support include directive paths before path are supported everywhere
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
