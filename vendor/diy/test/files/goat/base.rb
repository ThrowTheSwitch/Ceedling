# =========================================================================
#   Vendored third-party source, under its own copyright and license.
#   Not Ceedling code, and carries no Ceedling copyright banner.
#
#   DIY ⏩️ Atomic Object
#   License ⏩️ vendor/diy/LICENSE.txt
# =========================================================================


class Base
	def test_output(name)
		# See diy_context_test.rb
		File.open($goat_test_output_file, "a") do |f|
			f.puts "#{name} built"
		end
	end
end
