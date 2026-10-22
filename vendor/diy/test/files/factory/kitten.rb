# =========================================================================
#   Vendored third-party source, under its own copyright and license.
#   Not Ceedling code, and carries no Ceedling copyright banner.
#
#   DIY ⏩️ Atomic Object
#   License ⏩️ vendor/diy/LICENSE.txt
# =========================================================================


class Kitten
  attr_accessor :a,:b

  def initialize(a, b)
    @a = a
    @b = b
  end

  def meow
    "meow"
  end
end

