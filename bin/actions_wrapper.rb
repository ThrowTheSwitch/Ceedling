# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'thor'
require 'fileutils'

# Wrapper for handy Thor Actions
class ActionsWrapper
  include Thor::Base
  include Thor::Actions

  JUNK_FILE_EXCLUDE_REGEX = /(\.DS_Store)|(thumbs\.db)/

  # Most important mixin method is Thor::Actions class method `source_root()` we call externally

  def _directory(src, *args)
    # Build a single trailing options hash -- Thor's directory() only reads
    # the last argument as options, so any caller-supplied hash (e.g.
    # :force) and this default :exclude_pattern must live in the same hash.
    options = args.last.is_a?(Hash) ? args.pop : {}
    options[:exclude_pattern] ||= JUNK_FILE_EXCLUDE_REGEX
    args << options

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
