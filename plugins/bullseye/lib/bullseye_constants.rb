# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

BULLSEYE_ROOT_NAME           = 'bullseye'.freeze
BULLSEYE_TASK_ROOT           = BULLSEYE_ROOT_NAME + ':'
BULLSEYE_SYM                 = BULLSEYE_ROOT_NAME.to_sym

BULLSEYE_REPORT_NAMESPACE_SYM = :report

BULLSEYE_BUILD_PATH          = File.join(PROJECT_BUILD_ROOT, BULLSEYE_ROOT_NAME)
BULLSEYE_BUILD_OUTPUT_PATH   = File.join(BULLSEYE_BUILD_PATH, BUILD_OUT_DIR)
BULLSEYE_RESULTS_PATH        = File.join(BULLSEYE_BUILD_PATH, BUILD_RESULTS_DIR)
BULLSEYE_DEPENDENCIES_PATH   = File.join(BULLSEYE_BUILD_PATH, BUILD_DEPENDENCIES_DIR)
BULLSEYE_ARTIFACTS_PATH      = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, BULLSEYE_ROOT_NAME)
BULLSEYE_HTML_ARTIFACTS_PATH = File.join(BULLSEYE_ARTIFACTS_PATH, 'covhtml')

# Bullseye records each source's path in the .cov file relative to the .cov file's own
# directory, and region-exclusion glob patterns (covselect, and covsrc/covfn/covhtml's
# automatic honoring of covselect's persisted selections) match against that raw stored
# path. Bullseye's own docs recommend locating the coverage file at "the parent of all
# the directories containing source files" for exactly this reason. Ceedling's project
# root is that common ancestor for every source location a project can have (src/,
# test/, build/vendor/.../, build/test/runners/, etc.) — anywhere under build/artifacts/
# is not, since it's a descendant of build/ itself, which forces multi-level ../..
# prefixes into stored paths and breaks exclusion pattern matching. So, unlike every
# other Bullseye build artifact, the .cov file itself lives at project root, not under
# build/.
BULLSEYE_COVFILE_PATH        = 'test.cov'

# Vendor/framework sources never subject to coverage instrumentation or reporting
BULLSEYE_IGNORE_SOURCES      = ['unity', 'cmock', 'cexception']

TOOL_COLLECTION_BULLSEYE_TASKS = {
  :test_compiler  => TOOLS_BULLSEYE_COMPILER,
  :test_assembler => TOOLS_TEST_ASSEMBLER,
  :test_linker    => TOOLS_BULLSEYE_LINKER,
  :test_fixture   => TOOLS_BULLSEYE_FIXTURE
}

# Untested Sources Processing Modes
# :ignore  — Skip untested sources entirely (no logging, no compilation).
# :list    — Log untested source filepaths as a warning; do not compile them.
# :compile — Compile all untested sources with coverage instrumentation.
BULLSEYE_UNTESTED_SOURCES_IGNORE  = :ignore
BULLSEYE_UNTESTED_SOURCES_LIST    = :list
BULLSEYE_UNTESTED_SOURCES_COMPILE = :compile
BULLSEYE_UNTESTED_SOURCES_OPTIONS = [
  BULLSEYE_UNTESTED_SOURCES_IGNORE,
  BULLSEYE_UNTESTED_SOURCES_LIST,
  BULLSEYE_UNTESTED_SOURCES_COMPILE
]
