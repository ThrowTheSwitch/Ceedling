/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

TEST_CASE(25)
TEST_CASE(125)
TEST_CASE(5)
void test_should_handle_divisible_by_5_for_parameterized_test_case(int num) {
 TEST_ASSERT_EQUAL_MESSAGE(0, (num % 5), "All The Values Are Divisible By 5");
}

TEST_RANGE([5, 100, 5])
void test_should_handle_divisible_by_5_for_parameterized_test_range(int num) {
 TEST_ASSERT_EQUAL_MESSAGE(0, (num % 5), "All The Values Are Divisible By 5");
}

TEST_RANGE([10, 100, 10], [5, 10, 5])
void test_should_handle_a_divisible_by_b_for_parameterized_test_range(int a, int b) {
  TEST_ASSERT_EQUAL_MESSAGE(0, (a % b), "All The a Values Are Divisible By b");
}
