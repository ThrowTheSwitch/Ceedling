/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* The `nosanitize` filename segment is read by a build-time matcher, not
   decoration: spec/support/system/sanitizers/*.yml excludes it from ASan+UBSan
   instrumentation. This file writes past a heap allocation on purpose, for the
   sanitize plugin's specs (spec/system/support/sanitize_common_test_cases.rb),
   which instrument it themselves. Renaming it without that segment silently
   re-instruments it -- spec/integration/sanitizer_exclusions_spec.rb breaks the
   build if that happens. */

#include <stdlib.h>
#include "unity.h"
#include "example_file.h"

void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_adds_numbers(void) {
  TEST_ASSERT_EQUAL_INT(2, add_numbers(1,1));
}

void test_writes_past_its_buffer(void) {
  volatile int* buffer = malloc(4 * sizeof(int));
  buffer[4] = 1;
  free((void*)buffer);
}
