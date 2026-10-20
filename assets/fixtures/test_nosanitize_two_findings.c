/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* The `nosanitize` filename segment is read by a build-time matcher, not
   decoration: spec/support/system/sanitizers/*.yml excludes it from ASan+UBSan
   instrumentation. This file holds two test cases that each halt a sanitized
   test executable on purpose, for the sanitize plugin's specs
   (spec/system/support/sanitize_common_test_cases.rb), which instrument it
   themselves. The first halts the main run, so the second's finding is reached
   only by its backtrace rerun. Renaming it without that segment silently
   re-instruments it -- spec/integration/sanitizer_exclusions_spec.rb breaks the
   build if that happens. */

#include <stdint.h>
#include <stdlib.h>
#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

void test_writes_past_its_buffer(void) {
  volatile int* buffer = malloc(4 * sizeof(int));
  buffer[4] = 1;
  free((void*)buffer);
}

/* Left-shifting a value past its type's bit width is undefined behavior */
void test_shifts_too_far(void) {
  volatile uint8_t value = 128;
  volatile uint32_t result = value << 24;
  (void)result;
}
