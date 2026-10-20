# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

SANITIZE_ROOT_NAME              = 'sanitize'.freeze
SANITIZE_TASK_ROOT              = SANITIZE_ROOT_NAME + ':'
SANITIZE_SYM                    = SANITIZE_ROOT_NAME.to_sym unless defined?(SANITIZE_SYM)

SANITIZE_BUILD_PATH             = File.join(PROJECT_BUILD_ROOT, SANITIZE_ROOT_NAME)
SANITIZE_ARTIFACTS_PATH         = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, SANITIZE_ROOT_NAME)
