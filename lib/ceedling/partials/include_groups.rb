# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module Partials
  # A generated header's includes, split where the module's source includes the module's own
  # header. The leading group comes first. The following group comes after the header's items,
  # since the source meets those includes only after the header when it compiles.
  IncludeGroups = Struct.new(
    :leading,   # Array of Include ahead of the module's own content
    :following, # Array of Include the source names after the module's header
    keyword_init: true
  ) do
    def initialize(leading: [], following: [])
      super
    end

    # Splits a list at `boundary`, matched by identity, and leaves the boundary out
    def self.split(includes, boundary)
      index = includes.index { |include| include.equal?( boundary ) }
      return new( leading: includes[0...index], following: includes[(index + 1)..] )
    end

    # Every include, in order
    def to_a()
      return leading + following
    end

    # Both groups as include directives, for a freshness record
    def to_record()
      return { leading: leading.map( &:to_s ), following: following.map( &:to_s ) }
    end
  end unless const_defined?(:IncludeGroups, false)
end
