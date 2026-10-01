# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'

class Actionator

  constructor :file_wrapper, :loginator

  JUNK_FILE_EXCLUDE_REGEX = /(\.DS_Store)|(thumbs\.db)/

  attr_accessor :source_root, :destination_root

  def setup
  end

  def copy_file(source, destination, force: false, verbose: true)
  end

  def copy_directory(source, destination, force: false, verbose: true,
                     exclude_pattern: JUNK_FILE_EXCLUDE_REGEX)
  end

  def make_directory(destination, verbose: true)
  end

  def remove_directory(path, verbose: true)
  end

  def touch_file(path)
  end

  def chmod(path, mode, verbose: true)
  end

  def gsub_file(path, pattern, replacement, verbose: true)
  end

end
