# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake'
require 'stringio'

module CaptureHelpOutput
  def capture_display_tasks
    original_stdout = $stdout
    output_string = StringIO.new
    $stdout = output_string

    begin
      # Call the original method that writes directly to $stdout with printf()
      display_tasks_and_comments
    ensure
      # This block will always execute, even if an exception occurs
      $stdout = original_stdout
    end

    # Restore original stdout
    $stdout = original_stdout

    # Return the captured output
    output_string.string
  end
end

# On Windows, a `rule()`-matched task name containing a *second* colon (e.g.
# "release:compile:foo.c" from the ad hoc release:compile:<file>/release:assemble:<file>
# tasks -- lib/ceedling/rules_release.rake) makes File.mtime raise Errno::EINVAL instead
# of the Errno::ENOENT FileTask#needed?/#timestamp already rescue elsewhere. A rule()
# match is never a real file -- Rake synthesizes a FileTask named after the literal
# matched string -- so on POSIX, File.mtime on that nonexistent name correctly raises
# ENOENT and FileTask's own rescue treats it as "always stale, build it." Windows raises
# EINVAL instead specifically because a second colon in a path only parses as valid NTFS
# Alternate Data Stream syntax when followed by one of a handful of recognized stream-type
# tokens ($DATA, etc.) -- an arbitrary filename like "foo.c" isn't one, so the OS rejects
# the whole path as malformed rather than merely absent. (A single colon, as in every
# other rule()-matched task name in this codebase -- e.g. "test:TestFoo.c" -- parses as
# ordinary ADS "base:stream" syntax and correctly reports ENOENT when the base doesn't
# exist, which is why only these two release tasks are affected.) Wrapping both methods
# to treat EINVAL the same as ENOENT lets Rake's own existing "not really a file, build
# it" handling apply on Windows too, rather than crashing the whole build.
module Rake
  module ColonTaskNameFileTaskPatch
    def needed?
      super
    rescue Errno::EINVAL
      true
    end

    def timestamp
      super
    rescue Errno::EINVAL
      Rake::LATE
    end
  end

  FileTask.prepend( ColonTaskNameFileTaskPatch )
end
