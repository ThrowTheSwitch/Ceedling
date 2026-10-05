/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* The `nosanitize` filename segment is read by a build-time matcher, not
   decoration: spec/support/system/sanitizers/*.yml excludes it from ASan+UBSan
   instrumentation. This file commits undefined behavior on purpose and brings
   its own UBSan flags and halt-on-error wrapper with it (see the issue #1198
   case in spec/system/support/common_test_cases.rb); the suite-wide flags would
   collide with those. Renaming it without that segment silently re-instruments it --
   spec/integration/sanitizer_exclusions_spec.rb breaks the build if that
   happens. */

#include <stdint.h>

#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

/* Left-shifting a value past its type's bit width is undefined behavior --
   UBSan's -fsanitize=undefined flags it at runtime without a real crash
   occurring at the OS level. */
void test_shift_overflow(void) {
  volatile uint8_t value = 128;
  volatile uint32_t result = value << 24;
  (void)result;
}
