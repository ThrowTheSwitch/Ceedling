# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The directory Ceedling runs in, read once.
#
# A build resolves paths against the working directory tens of thousands of times, and
# asking the operating system for it costs tens of microseconds on macOS. Ceedling changes
# directory only through `chdir`, which forgets the remembered directory going in and
# coming out.
#
# No dependency on DIY, so the launcher in bin/ shares it.
module WorkingDir

  @lock = Mutex.new
  @path = nil

  # The working directory with every symlink resolved
  def self.path
    return @path || @lock.synchronize { @path ||= File.realpath( Dir.pwd ).freeze }
  end

  # Changes directory for the block, as Dir.chdir does, so paths resolved inside it resolve
  # against the new directory and paths resolved after it against the old one
  def self.chdir(dir, &block)
    forget
    return Dir.chdir( dir, &block )
  ensure
    forget
  end

  # The next `path` reads the working directory again
  def self.forget
    @lock.synchronize { @path = nil }
  end

end
