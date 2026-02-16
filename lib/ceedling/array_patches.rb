# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module ArrayPatches
  # Add Array#intersect? for Ruby 3.0 but use built-in provided by 3.1+
  # Query if any elements are in common.
  unless Array.method_defined?(:intersect?)
    Array.class_eval do
      def intersect?(other)
        !(self & other).empty?
      end
    end
  end

  Array.class_eval do
    # Query if all elements are in common.
    def overlap?(other)
      return (self & other).size() == other.size()
    end
  end
end

# Auto-load patches
ArrayPatches