# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

BEGIN {
  require 'io/nonblock'

  # If possible, capture standard data streams non-blocking mode at startup (to be restored at shutdown).
  # A sophisticated build setup (e.g. CI) may have intended this change on either side of Ceedling, 
  # but it will cause trouble for Ceedling itself.

  if STDOUT.respond_to?(:nonblock?) # Non-blocking mode query not implemented on all platforms
    STDIN_STARTUP_NONBLOCKING_MODE = (STDIN.nonblock?).freeze if !defined?( STDIN_STARTUP_NONBLOCKING_MODE )
    STDOUT_STARTUP_NONBLOCKING_MODE = (STDOUT.nonblock?).freeze if !defined?( STDOUT_STARTUP_NONBLOCKING_MODE )
    STDERR_STARTUP_NONBLOCKING_MODE = (STDERR.nonblock?).freeze if !defined?( STDERR_STARTUP_NONBLOCKING_MODE )
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

  def stdout_puts(string)
    $stdout.puts(string)
  end

  def stderr_puts(string)
    $stderr.puts(string)
  end

end

END {
  require 'io/nonblock'

  # If they were captured, reset standard data streams' non-blocking mode to the setting captured at startup
  STDIN.nonblock = STDIN_STARTUP_NONBLOCKING_MODE if defined?( STDIN_STARTUP_NONBLOCKING_MODE )
  STDOUT.nonblock = STDOUT_STARTUP_NONBLOCKING_MODE if defined?( STDOUT_STARTUP_NONBLOCKING_MODE )
  STDERR.nonblock = STDERR_STARTUP_NONBLOCKING_MODE if defined?( STDERR_STARTUP_NONBLOCKING_MODE )
}
