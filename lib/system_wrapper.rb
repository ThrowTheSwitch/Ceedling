
class SystemWrapper

  def search_paths
    return ENV['PATH'].split(File::PATH_SEPARATOR)
  end

  def cmdline_args
    return ARGV
  end

  def env_set(name, value)
    ENV[name] = value
  end
  
  def env_get(name)
    return ENV[name]
  end

  def shell_execute(command)
    return {
      :output => `#{command}`,
      :exit_code => ($?.exitstatus)
    }
  end
  
  def require_file(path)
    require(path)
  end

end
