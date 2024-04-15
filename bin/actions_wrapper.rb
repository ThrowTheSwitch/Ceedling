# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'thor'
require 'fileutils'

# Wrapper for handy Thor Actions
class ActionsWrapper
  include Thor::Base
  include Thor::Actions

  source_root( CEEDLING_ROOT )

  def _directory(src, *args)
    directory( src, *args )
  end

  def _copy_file(src, *args)
    copy_file( src, *args )
  end

  def _touch_file(src)
    FileUtils.touch(src)
  end

  def _chmod(src, mode, *args)
    chmod( src, mode, *args )
  end

  def _empty_directory(dest, *args)
    empty_directory( dest, *args )
  end

  def _gsub_file(path, flag, *args, &block)
    gsub_file( path, flag, *args, &block )
  end

end
