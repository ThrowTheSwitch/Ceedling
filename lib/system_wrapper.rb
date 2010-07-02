
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

  def shell_execute(command, options={:stderr_capture => false})
    # this is a hack to redirect $stderr as all other mechanisms so far fail to do anything
    $stderr.reopen(PROJECT_STDERR_FILEPATH, 'w') if (options[:stderr_capture])

    shell  = `#{command}`
    stderr = ''
    
    if (options[:stderr_capture])
      stderr = File.read(PROJECT_STDERR_FILEPATH).strip
      stderr += "\n" if (stderr.length > 1)
    end
    
    result = {
      :output =>  stderr + shell,
      :exit_code => ($?.exitstatus)
    }

    $stderr.reopen(IO.new(2)) if (options[:stderr_capture])
    
    return result
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
