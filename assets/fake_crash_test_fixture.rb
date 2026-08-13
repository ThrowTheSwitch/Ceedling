# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Deliberately ignores the real test executable path it's given and never runs it --
# simulates a custom :test_fixture wrapper whose own crash-detection machinery (e.g. a
# sanitizer's halt_on_error) kills the process before Unity ever gets to print its
# summary. Exists to reproduce issue #1198 without needing a real sanitizer toolchain:
# a diagnostic backtrace retry left at its default configuration runs the real
# executable directly instead, unaffected by this fixture, and legitimately passes.
exit 1
