# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Plugin
  attr_reader :name, :environment
  attr_accessor :plugin_objects

  def initialize(system_objects, name, root_path)
    @environment = []
    @ceedling = system_objects
    @plugin_root_path = root_path
    @name = name
    self.setup
  end

  # Override to prevent exception handling from walking & stringifying the object variables.
  # Plugin's object variables are gigantic and produce a flood of output.
  def inspect
    return this.class.name
  end

  def setup; end
  
  def summary; end

end
