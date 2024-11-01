# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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
