/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

// A second test file covering the same source as test_example_file_success.c.
// Ceedling builds one executable per test file, and both link against
// example_file.c, producing two sets of .gcda coverage data for the same
// functions -- used to exercise gcovr's merge-mode-functions behavior.

#include "unity.h"
#include "example_file.h"

void setUp(void) {}
void tearDown(void) {}

void test_difference_between_two_numbers(void)
{
  TEST_ASSERT_EQUAL_INT(0, difference_between_numbers(1, 1));
}
