# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


VALGRIND_ROOT_NAME              = 'valgrind'.freeze
VALGRIND_TASK_ROOT              = VALGRIND_ROOT_NAME + ':'
VALGRIND_SYM                    = VALGRIND_ROOT_NAME.to_sym unless defined?(VALGRIND_SYM)

VALGRIND_BUILD_PATH             = File.join(PROJECT_BUILD_ROOT, "test")
VALGRIND_BUILD_OUTPUT_PATH      = File.join(VALGRIND_BUILD_PATH, "out")
VALGRIND_ARTIFACTS_PATH         = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, VALGRIND_ROOT_NAME)
