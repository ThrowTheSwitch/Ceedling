require 'rbconfig'    
require 'open3'

class SystemWrapper

  # static method for use in defaults
  def self.windows?
    return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?(RbConfig)
    return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
  end

  def self.time_stopwatch_s
    # Wall clock time that can be adjusted for a variety of reasons and lead to
    # unexpected negative durations -- only option on Windows.
    return Time.now() if SystemWrapper.windows?

    # On Posix systems, this time value is a steadily increasing count from
    # a known system event (usually restart) and is more better
    return Process.clock_gettime( Process::CLOCK_MONOTONIC, :float_second )
  end

  # class method so as to be mockable for tests
  def windows?
    return SystemWrapper.windows?
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

  def shell_capture3(command:, boom:false) 
    # Beginning with later versions of Ruby2, simple exit codes were replaced
    # by the more capable and robust Process::Status.
    # Parts of Process::Status's behavior is similar to an integer exit code in
    # some operations but not all.
    exit_code = 0
    begin
      # Run the command but absorb any exceptions and capture error info instead
      stdout, stderr, status = Open3.capture3( command )
    rescue => err
      stderr = err
      exit_code = -1
    end

    # If boom, then capture the actual exit code, otherwise leave it as zero
    # as though execution succeeded
    exit_code = status.exitstatus.freeze if boom

    # (Re)set the system exit code
    $exit_code = exit_code

    return {
      # Combine stdout & stderr streams for complete output
      :output    => (stdout + stderr).freeze,
      
      # Relay full Process::Status
      :status    => status.freeze,
      
      # Provide simple exit code accessor
      :exit_code => exit_code.freeze
    }
  end

  def shell_backticks(command:, boom:false)
    output = `#{command}`.freeze
    $exit_code = ($?.exitstatus).freeze if boom
    return {
      :output    => output.freeze,
      :exit_code => ($?.exitstatus).freeze
    }
  end

  def shell_system(command:, args:[], verbose:false, boom:false)
    result = nil

    if verbose
      # Allow console output
      result = system( command, *args )
    else
      # Shush the console output
      result = system( command, *args, [:out, :err] => File::NULL )
    end

    $exit_code = ($?.exitstatus).freeze if boom
    return {
      :result    => result.freeze,
      :exit_code => ($?.exitstatus).freeze
    }
  end

  def add_load_path(path)
    $LOAD_PATH.unshift(path)
  end

  def require_file(path)
    require(path)
  end

  def ruby_success?
    # We are successful if we've never had an exit code that went boom (either because it's empty or it was 0)
    return ($exit_code.nil? || ($exit_code == 0)) && ($!.nil? || $!.is_a?(SystemExit) && $!.success?)
  end

  def constants_include?(item)
    # forcing to strings provides consistency across Ruby versions
    return Object.constants.map{|constant| constant.to_s}.include?(item.to_s)
  end

end
