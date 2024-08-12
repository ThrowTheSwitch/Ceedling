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

  JUNK_FILE_EXCLUDE_REGEX = 

  # Most important mixin method is Thor::Actions class method `source_root()` we call externally

  def _directory(src, *args)
    # Insert exclusion of macOS and Windows preview junk files if an exclude pattern is not present
    # Thor's use of args is an array of call arguments, some of which can be single key/value hash options
    if !args.any? {|h| h.class != Hash ? false : !h[:exclude_pattern].nil?}
      args << {:exclude_pattern => /(\.DS_Store)|(thumbs\.db)/}
    end

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
