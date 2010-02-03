
class SystemWrapper

  def search_paths
    return ENV['PATH'].split(File::PATH_SEPARATOR)
  end

  def cmdline_args
    return ARGV
  end

  def shell_execute(command)
    return {
      :output => `#{command}`,
      :exit_code => $?.exitstatus
    }
  end
  
  def require_file(path)
    require(path)
  end

end
