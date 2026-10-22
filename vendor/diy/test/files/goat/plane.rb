# =========================================================================
#   Vendored third-party source, under its own copyright and license.
#   Not Ceedling code, and carries no Ceedling copyright banner.
#
#   DIY ⏩️ Atomic Object
#   License ⏩️ vendor/diy/LICENSE.txt
# =========================================================================


require 'base'
class Plane < Base
	constructor :wings, :strict => true
	def setup
		test_output "plane"
	end		
end
