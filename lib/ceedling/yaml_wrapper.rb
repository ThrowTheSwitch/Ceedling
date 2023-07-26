require 'yaml'
require 'erb'


class YamlWrapper

  def load_options()
    yaml_version = YAML::VERSION[0].to_i  # Extract major version number of YAML
    if yaml_version > 3
      { aliases: true }
    else
      { }
    end
  end

  def load(filepath)
    source = ERB.new(File.read(filepath)).result
    begin
      return YAML.load(source, **load_options)
    rescue ArgumentError
      return YAML.load(source)
    end
  end

  def load_string(source)
    begin
      return YAML.load(source, **load_options)
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
