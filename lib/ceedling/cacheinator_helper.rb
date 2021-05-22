
class CacheinatorHelper

  constructor :file_wrapper, :yaml_wrapper
  
  def diff_cached_config?(cached_filepath, hash)
    return false if ( not @file_wrapper.exist?(cached_filepath) )
    return true if (@yaml_wrapper.load(cached_filepath) != hash)
    return false
  end

end
