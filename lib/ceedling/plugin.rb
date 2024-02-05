
class Plugin
  attr_reader :name, :environment
  attr_accessor :plugin_objects

  def initialize(system_objects, name)
    @environment = []
    @ceedling = system_objects
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
