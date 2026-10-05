/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* The `nosanitize` filename segment is read by a build-time matcher, not
   decoration: spec/support/system/sanitizers/*.yml excludes it from ASan+UBSan
   instrumentation. This file fails to compile on purpose, so it never reaches a
   sanitizer at all -- it carries the segment so the convention covers every
   deliberately-broken fixture uniformly rather than by case-by-case reasoning
   about which ones can reach a runtime.
   spec/integration/sanitizer_exclusions_spec.rb breaks the build if this file is
   renamed without that segment, or loses this comment. */

#include "unity.h"
#include "example_file.h"

void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_adds_numbers(void) {
  TEST_ASSERT_EQUAL_INT(2, add_numbers(1,1) //Removed semicolon & parenthesis to make a compile error.
}

void test_add_numbers_will_fail(void) {
  TEST_ASSERT_EQUAL_INT(2, add_numbers(2,2));
}
