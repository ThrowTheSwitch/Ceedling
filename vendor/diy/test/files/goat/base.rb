class Base
	def test_output(name)
		# See diy_context_test.rb
		File.open($goat_test_output_file, "a") do |f|
			f.puts "#{name} built"
		end
	end
end
