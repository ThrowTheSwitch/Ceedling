# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/working_dir'

class FileSystemWrapper

  # Through WorkingDir, so paths resolved inside the block resolve against `path`
  def cd(path, &block)
    return WorkingDir.chdir( path, &block )
  end

end
