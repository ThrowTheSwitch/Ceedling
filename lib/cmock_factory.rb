require 'cmock'

class CmockFactory
  
  def manufacture(cmock_config)
    return CMock.new(cmock_config)
  end

end
