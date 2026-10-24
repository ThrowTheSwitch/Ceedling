# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Turns a per-file test task's name (test:, gen:mocks:, gcov:, valgrind:, and the rest) into
# the test name file lookup needs. A directory typed ahead of the name tells same-named tests
# apart, so it is kept, and only the file name gets the test file prefix.
module TestTaskName

  def self.test_name(task_name, root:, extensions: EXTENSION_SOURCE, prefix: PROJECT_TEST_FILE_PREFIX)
    test = task_name.strip.delete_prefix( root )

    # At most one configured extension ends the name, so trying each in turn is safe
    extensions.each { |ext| test = test.chomp( ext ) }

    # A Windows-style name under a POSIX Ruby (WSL, Cygwin) has backslashes File won't split on
    test = test.tr( '\\', '/' )

    dir  = File.dirname( test )
    base = File.basename( test )
    base = prefix + base unless base.start_with?( prefix )

    return (dir == '.') ? base : File.join( dir, base )
  end

end
