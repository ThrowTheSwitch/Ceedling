require 'cmock'

class CmockBuilder
  
  attr_accessor :cmock
  attr_reader :cmock_config
  
  def setup 
    @cmock = nil
    @cmock_config = nil
  end
  
  def manufacture(cmock_config)
    @cmock = CMock.new(cmock_config)
    @cmock_config = cmock_config.clone
  end

  def clone_mock_generator(cmock_config)
    return @cmock.class.new(cmock_config)
  end

end
