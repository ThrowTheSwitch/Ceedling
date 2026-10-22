/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "example_file_with_statics.c"

void setUp(void) {}
void tearDown(void) {}

void test_calculate_product_via_direct_source_include(void) {
  TEST_ASSERT_EQUAL_INT(6, calculate_product(2, 3));
  TEST_ASSERT_EQUAL_INT(0, calculate_product(0, 5));
}
