# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PluginManagerHelper

  def include?(plugins, name)
		include = false
		plugins.each do |plugin|
			if (plugin.name == name)
				include = true
				break
			end
		end
		return include
  end

  def instantiate_plugin(plugin, system_objects, name, root_path)
    return eval( "#{plugin}.new(system_objects, name, root_path)" )
  end

end
