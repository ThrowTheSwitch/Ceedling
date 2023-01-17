require 'erb'

class ErbWrapper
  def generate_file(template, data, output_file)
    File.open(output_file, "w") do |f|
      f << ERB.new(template, trim_mode: "<>").result(binding)
    end
  end
end