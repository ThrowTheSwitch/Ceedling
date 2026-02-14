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

  def initialize(filepath, full_path: false)
    @filepath = filepath.gsub(/#\s*include/, '')
    # Remove any quotation marks from an extracted user include directive
    @filepath.gsub!(/"/, '')
    # Remove any angle brackets from an extracted system include directive
    @filepath.gsub!(/</, '')
    @filepath.gsub!(/>/, '')
    # Whitespace cleanup
    @filepath.strip!()

    raise ArgumentError, "Empty include filepath" if @filepath.empty?

    @filename = File.basename(@filepath)
    @full_path = full_path
  end

  # Abstract method to be implemented by subclasses
  def to_s
    raise NotImplementedError, "Subclasses must implement to_s()"
  end

  # Returns the configured entry to use in the include directive
  def include
    @full_path ? @filepath : @filename
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
