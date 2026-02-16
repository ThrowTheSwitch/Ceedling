# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Base class for C header includes
class Include
  attr_reader :filepath
  attr_reader :filename

  # Initialize an Include object from a C include statement or simple filepath.
  #
  # @param statement [String] A C include statement (e.g., '#include "header.h"', 
  #   '#include <stdio.h>'), a quoted/bracketed filepath (e.g., '"header.h"', 
  #   '<stdio.h>'), or a plain filepath (e.g., 'path/to/header.h')
  # @param full_path [Boolean] If true, use the full filepath in the include 
  #   directive; if false, use only the filename (default: false)
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

  private

  # Returns the configured entry to use in the include directive
  def include()
    @full_path ? @filepath : @filename
  end

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
