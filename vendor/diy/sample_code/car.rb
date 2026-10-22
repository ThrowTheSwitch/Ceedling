# =========================================================================
#   Vendored third-party source, under its own copyright and license.
#   Not Ceedling code, and carries no Ceedling copyright banner.
#
#   DIY ⏩️ Atomic Object
#   License ⏩️ vendor/diy/LICENSE.txt
# =========================================================================


class Car
  attr_reader :engine, :chassis
  def initialize(arg_hash)
    @engine = arg_hash[:engine]
    @chassis = arg_hash[:chassis]
  end
end
