
class SystemWrapper

  def search_paths
    return ENV['PATH'].split(File::PATH_SEPARATOR)
  end

end
