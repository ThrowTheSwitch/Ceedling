/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* The `nosanitize` filename segment is read by a build-time matcher, not
   decoration: spec/support/system/sanitizers/*.yml excludes it from ASan+UBSan
   instrumentation. This file leaks an allocation on purpose, for the sanitize
   plugin's specs (spec/system/support/sanitize_common_test_cases.rb), which
   instrument it themselves. Every test case passes; the leak is found at exit.
   Renaming it without that segment silently re-instruments it --
   spec/integration/sanitizer_exclusions_spec.rb breaks the build if that
   happens. */

#include <stdlib.h>
#include "unity.h"
#include "example_file.h"

void setUp(void) {}
void tearDown(void) {}

/* Volatile, so the compiler keeps an allocation nothing reads */
static void* volatile leaked;

void test_add_numbers_adds_numbers(void) {
  TEST_ASSERT_EQUAL_INT(2, add_numbers(1,1));
}

void test_loses_its_allocation(void) {
  leaked = malloc(32);
  leaked = NULL;
}
