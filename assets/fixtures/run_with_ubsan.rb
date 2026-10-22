# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Enables UBSan's halt-on-error, then execs the real test executable in this script's
# own place rather than as a child process -- this process's PID becomes the test
# executable's PID, so the real Process::Status Ceedling observes is the test
# executable's own. Regression fixture for issue #1198: a diagnostic backtrace retry
# runs through a separate, unwrapped default tool that never sees this setting, so it
# can legitimately recover from the same undefined behavior instead of halting on it.
ENV['UBSAN_OPTIONS'] = 'halt_on_error=1'
exec(*ARGV)
