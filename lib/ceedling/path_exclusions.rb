# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/path_spellings'

# What collection leaves out, each a set of spellings: `-:` entries' places, outweighed by
# an entry based nearer; excluded places, outweighed by an entry based no farther away; and
# reserved places, never collected
PathExclusions = Struct.new( :minus, :excluded, :reserved ) do
  def self.of(minus, excluded, reserved)
    return new( *[minus, excluded, reserved].map { |paths| PathSpellings.of( paths ) } )
  end

  def none?
    return [minus, excluded, reserved].all?( &:empty? )
  end

  # Whether a place, by `spellings` of it and `distance` below the base of the entry naming
  # it, is collected
  def keeps?(spellings, distance)
    return distance < PathSpellings.nearer( spellings, minus ) &&
           distance <= PathSpellings.nearer( spellings, excluded ) &&
           PathSpellings.nearer( spellings, reserved ) == Float::INFINITY
  end
end
