

BEGIN {
  require 'io/nonblock'

  # If possible, capture standard data streams non-blocking mode at startup (to be restored at shutdown).
  # A complex build setup may have intended this change, but it will cause trouble for Ceedling.

  if STDOUT.respond_to?(:nonblock?) # Non-blocking mode query not implemented on all platforms
    STDIN_STARTUP_NONBLOCKING_MODE = (STDIN.nonblock?).freeze
    STDOUT_STARTUP_NONBLOCKING_MODE = (STDOUT.nonblock?).freeze
    STDERR_STARTUP_NONBLOCKING_MODE = (STDERR.nonblock?).freeze
  end

  # Ensure standard data streams are in blocking mode for Ceedling runs
  STDIN.nonblock = false
  STDOUT.nonblock = false
  STDERR.nonblock = false
}

class StreamWrapper

  def initialize
    STDOUT.sync
    STDERR.sync
  end

  def stdout_override(&fnc)
    @stdout_overide_fnc = fnc
  end

  def stdout_puts(string)
    if @stdout_overide_fnc
      @stdout_overide_fnc.call(string)
    else
      $stdout.puts(string)
    end
  end

  def stderr_puts(string)
    $stderr.puts(string)
  end

end

END {
  require 'io/nonblock'

  # If they were captured, reset standard data streams' non-blocking mode to the setting captured at startup
  STDIN.nonblock = STDIN_STARTUP_NONBLOCKING_MODE if defined?(STDIN_STARTUP_NONBLOCKING_MODE)
  STDOUT.nonblock = STDOUT_STARTUP_NONBLOCKING_MODE if defined?(STDOUT_STARTUP_NONBLOCKING_MODE)
  STDERR.nonblock = STDERR_STARTUP_NONBLOCKING_MODE if defined?(STDERR_STARTUP_NONBLOCKING_MODE)
}
