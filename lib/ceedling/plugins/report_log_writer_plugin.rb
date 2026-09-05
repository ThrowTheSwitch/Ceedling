# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'

# Shared base for plugins that collect string fragments during a build --
# behind a mutex, since fragments arrive from concurrent build threads --
# and flush them to one artifact file per collected entry at post_build or
# post_error. A subclass owns its own collection's shape (what it collects
# and how it's keyed); this base owns the mutex discipline and the actual
# file write, so the two responsibilities can't quietly drift apart the way
# they previously could when each plugin hand-rolled both itself.
class ReportLogWriterPlugin < Plugin

  # `Plugin` setup()
  def setup
    @mutex        = Mutex.new
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator    = @ceedling[:loginator]
    @reportinator = @ceedling[:reportinator]
  end

  private

  # Ensures <build root>/artifacts/<context>/ exists and returns the full
  # filepath for `filename` inside it.
  def artifact_filepath(context, filename)
    path = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s)
    @file_wrapper.mkdir(path)
    File.join(path, filename)
  end

  # Logs a heading, then either reports `empty_message` or runs the
  # caller's block to write each artifact. Both the emptiness check and the
  # write pass happen under `@mutex` -- the same guard a subclass's own
  # collection-time write already holds -- so a build thread still
  # finishing its own collection can never interleave with this read/write
  # pass the way an unguarded read previously could.
  def flush_log(heading:, empty_message:, empty:)
    @loginator.log(@reportinator.generate_heading(heading))

    is_empty = false
    @mutex.synchronize { is_empty = empty.call }

    if is_empty
      @loginator.log("#{empty_message}\n")
      return
    end

    @mutex.synchronize { yield }

    # Whitespace at command line after progress messages
    @loginator.log('')
  end

  def write_artifact(filepath, contents)
    @loginator.log(@reportinator.generate_progress("Generating artifact #{filepath}"))
    @file_wrapper.write(filepath, contents)
  end

end
