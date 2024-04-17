# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'thing'

class ThingBuilder
  @@builder_count = 0
  
  def self.reset_builder_count
    @@builder_count = 0
  end
  
  def self.builder_count
    @@builder_count
  end
  
  def initialize
    @@builder_count += 1
  end
  
  def build(name, ability)
    Thing.new(:name => name, :ability => ability)
  end
  
  def build_default
    Thing.new(:name => "Thing", :ability => "nothing")
  end  
end