
class SystemWrapper

  def search_paths
    return ENV['PATH'].split(File::PATH_SEPARATOR)
  end

  def shell_execute(command)
    return {
      :output => `#{command}`,
      :exit_code => $?.exitstatus
    }
  end

end
