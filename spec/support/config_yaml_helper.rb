# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/yaml_wrapper'

# Parses project configuration written as YAML, as a project file states it. A spec
# reads like the configuration it describes and receives the symbol-keyed hash Ceedling
# processes. Parsing a string touches no filesystem, so unit specs use it too.
module ConfigYamlHelper
  def config_from_yaml(yaml)
    return YamlWrapper.new( { file_wrapper: nil } ).load_string( yaml )
  end
end
