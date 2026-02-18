# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Includes
  # Class method to convert mixed list of Include objects into an order-preserving list of hashes
  #
  # @param includes [Array<Include>] List of UserInclude and SystemInclude objects
  # @return [Array<Hash>] Array of hashes, each with 'type' and 'path' keys
  # @example
  #   includes = [
  #     UserInclude.new("header.h"),
  #     SystemInclude.new("stdio.h"),
  #     UserInclude.new("module.h")
  #   ]
  #   Include.to_hash(includes)
  #   # => [
  #   #   { 'type' => 'user', 'path' => 'header.h' },
  #   #   { 'type' => 'system', 'path' => 'stdio.h' },
  #   #   { 'type' => 'user', 'path' => 'module.h' }
  #   # ]
  def self.to_hashes(includes)
    return includes.map do |inc|
      {
        'type' => inc.is_a?(UserInclude) ? 'user' : 'system',
        'path' => inc.filepath
      }
    end
  end

  # Class method to convert a list of hashes back into Include objects
  #
  # @param hashes [Array<Hash>] Array of hashes with 'type' and 'path' keys
  # @return [Array<Include>] List of UserInclude and SystemInclude objects
  # @raise [ArgumentError] If hash is missing required keys or has invalid type
  # @example
  #   hashes = [
  #     { 'type' => 'user', 'path' => 'header.h' },
  #     { 'type' => 'system', 'path' => 'stdio.h' },
  #     { 'type' => 'user', 'path' => 'module.h' }
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
      raise ArgumentError, "Hash missing 'path' key" unless hash.key?('path')
      
      case hash['type']
      when 'user'
        UserInclude.new(hash['path'])
      when 'system'
        SystemInclude.new(hash['path'])
      else
        raise ArgumentError, "Invalid include type: #{hash['type']}. Must be 'user' or 'system'"
      end
    end
  end

  # Class method to extract all matching includes by filename pattern
  def self.filter(includes, pattern)
    includes.select { |include| include.filename =~ pattern }
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
    # Remove duplicates
    includes.uniq!

    # Apply custom rejection with access to full list if block provided
    if block_given?
      includes.reject! { |include| block.call(include, includes) }
    end

    # Ensure system includes come first
    self.sort!(includes)

    return includes
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

  # Initialize an Include object from a C include statement or simple filepath.
  #
  # @param statement [String] A C include statement. Examples:
  #  - #include "header.h"
  #  - #include <stdio.h>
  #  - A quoted/bracketed filepath (e.g., '"header.h"' or <stdio.h>')
  #  - A plain filepath (e.g., 'path/to/header.h')
  # @param full_path [Boolean] (default: false)
  #  - If true, use the full filepath in the include directive
  #  - If false, use only the filename
  # @raise [ArgumentError] If the statement is empty or becomes empty after cleaning
  def initialize(statement, full_path: false)
    @filepath = clean(statement)

    raise ArgumentError, "Empty include statement" if @filepath.empty?

    @filename = File.basename(@filepath)
    @full_path = full_path
  end

  # Abstract method to be implemented by subclasses
  def to_s()
    raise NotImplementedError, "Subclasses must implement to_s()"
  end

  # Equality operator -- compares the include value with a string
  def ==(other)
    case other
    when String
      include == other
    when Include
      # Distinguish type of Include objects as well as content of the include
      self.class == other.class && include == other.include
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
    @full_path ? @filepath : @filename
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
    _line.strip!()

    return _line
  end
end

# UserInclude generates #include "header.h" (with quotes)
class UserInclude < Include
  def to_s()
    "#include \"#{include}\""
  end
end

# SystemInclude generates #include <header.h> (with brackets)
class SystemInclude < Include
  def to_s()
    "#include <#{include}>"
  end
end
