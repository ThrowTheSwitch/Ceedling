require 'cmock'

class CmockBuilder
  
  attr_writer :default_config
  
  def setup 
    @default_config = nil
  end

  def get_default_config
    return @default_config.clone
  end
  
  def manufacture(config)
    return CMock.new(config)
  end

end
