# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/working_dir'

# WorkingDir reads the working directory once, and Ceedling changes directory only through
# WorkingDir.chdir. Specs change directory in-process with Dir.chdir all the time, so here
# every Dir.chdir forgets the working directory too, and each spec's paths resolve against
# the directory it is in. `untracked` suspends that, so a spec can show what Ceedling
# itself does.
module WorkingDirTracking

  @paused = false

  def self.untracked
    previous = @paused
    @paused  = true
    yield
  ensure
    @paused = previous
  end

  def self.forget
    WorkingDir.forget unless @paused
  end

  module DirChdir
    def chdir(*args)
      WorkingDirTracking.forget
      return super unless block_given?

      super( *args ) do |*yielded|
        WorkingDirTracking.forget
        yield( *yielded )
      ensure
        WorkingDirTracking.forget
      end
    ensure
      WorkingDirTracking.forget
    end
  end

end

Dir.singleton_class.prepend( WorkingDirTracking::DirChdir )
