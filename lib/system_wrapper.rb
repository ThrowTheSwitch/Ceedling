
class SystemWrapper

  def eval(string)
    return Object.module_eval("\"" + string + "\"")
  end

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

  def time_now
    return Time.now.asctime
  end

  def shell_execute(command)
    return {
      :output => `#{command}`,
      :exit_code => ($?.exitstatus)
    }
  end
  
  def add_load_path(path)
    $LOAD_PATH.unshift(path)
  end
  
  def require_file(path)
    require(path)
  end

  def ruby_success
    return ($!.nil? || $!.is_a?(SystemExit) && $!.success?)
  end

end
