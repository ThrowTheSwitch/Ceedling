# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

  # All three arguments are read by the eval string below, which RuboCop cannot see
  # into. The cop reads them as unused and offers to rename them with underscore
  # prefixes. Accepting that rename leaves the eval referencing locals that no longer
  # exist, so no plugin can be instantiated. Do not autocorrect this line.
  def instantiate_plugin(plugin, system_objects, name, root_path) # rubocop:disable Lint/UnusedMethodArgument
    return eval( "#{plugin}.new(system_objects, name, root_path)" )
  end

end
