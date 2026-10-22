# =========================================================================
#   Vendored third-party source, under its own copyright and license.
#   Not Ceedling code, and carries no Ceedling copyright banner.
#
#   DIY ⏩️ Atomic Object
#   License ⏩️ vendor/diy/LICENSE.txt
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