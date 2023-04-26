require 'yaml'
require 'erb'


class YamlWrapper

  def load(filepath)
    source = ERB.new(File.read(filepath)).result
    begin
      return YAML.load(source, aliases: true)
    rescue ArgumentError
      return YAML.load(source)
    end
  end

  def load_string(source)
    begin
      return YAML.load(source, aliases: true)
    rescue ArgumentError
      return YAML.load(source)
    end
  end

  def dump(filepath, structure)
    File.open(filepath, 'w') do |output|
      YAML.dump(structure, output)
    end
  end

end
