
class Plugin

  def initialize(system_objects)
    @system_objects = system_objects
    self.setup
  end

  def setup
  end

  def pre_test_execute(arg_hash)
  end
  
  def post_test_execute(arg_hash)
  end

  def post_build
  end
    

end
