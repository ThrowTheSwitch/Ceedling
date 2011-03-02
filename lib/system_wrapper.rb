require 'rbconfig'

class SystemWrapper

  # static method for use in defaults
  def self.is_windows?
    return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
  end

  # class method so as to be mockable for tests
  def is_windows?
    return SystemWrapper.is_windows?
  end
  
  def module_eval(string)
    return Object.module_eval("\"" + string + "\"")
  end

  def eval(string)
    return eval(string)
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
      :output =>  `#{command}`,
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

  def constants_include?(item)
    # forcing to strings provides consistency across Ruby versions
    return Object.constants.map{|constant| constant.to_s}.include?(item.to_s)
  end
  
end
