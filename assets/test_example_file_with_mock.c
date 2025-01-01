/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "example_file_call.h"
// mock header should have higher priority than real file
#include "example_file.h"
#include "mock_example_file.h"

void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_adds_numbers(void) {
  add_numbers_ExpectAndReturn(1, 1, 2);
  TEST_ASSERT_EQUAL_INT(2, call_add_numbers(1, 1));
}
