# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Writes logs that hold only the current build's entries, such as gdb crash backtraces and
# sanitizer findings. A build's first write to a log replaces whatever an earlier build left
# there, and its later writes append. Build threads share one writer, so deciding first or
# later and writing happen together under one lock, and an append never lands before the
# write that replaces the file.
class BuildLogWriter

  constructor :file_wrapper

  def setup
    @written = []
    @mutex   = Mutex.new
  end

  # `separator` goes between entries appended to one log
  def write(filepath, text, separator: '')
    @mutex.synchronize do
      first = !@written.include?( filepath )
      @written << filepath if first

      @file_wrapper.mkdir_for( filepath )
      @file_wrapper.write( filepath, first ? text : separator + text, first ? 'w' : 'a' )
    end
  end

end
