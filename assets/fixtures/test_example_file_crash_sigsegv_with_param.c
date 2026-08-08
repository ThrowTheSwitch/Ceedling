/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include <signal.h>
#include "unity.h"
#include "example_file.h"


void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_will_fail(void) {
  // Platform-independent way of forcing a crash
  // NOTE: Avoid `nullptr` as it is a keyword in C23
  uint32_t* a_null_pointer = (void*)0;
  uint32_t i = *a_null_pointer;
  TEST_ASSERT_EQUAL_INT(2, add_numbers(i,2));
}

// Regression coverage for issue #1185: a parameterized test defined after a
// crashing test in the same file must still report its own real PASS/FAIL
// results rather than being swept up as "crashed" alongside the actual crash.
TEST_CASE(5, 3, 2)
TEST_CASE(10, 4, 6)
TEST_CASE(0, 0, 0)
void test_difference_between_numbers_is_correct(int a, int b, int expected) {
  TEST_ASSERT_EQUAL_INT(expected, difference_between_numbers(a, b));
}
