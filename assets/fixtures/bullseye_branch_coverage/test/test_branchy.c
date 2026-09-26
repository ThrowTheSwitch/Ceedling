/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Exercises one function and one decision outcome only. See src/branchy.c. */

#include "unity.h"
#include "branchy.h"

void setUp(void) {}
void tearDown(void) {}

void test_classify_returns_one_for_large_values(void) {
  TEST_ASSERT_EQUAL_INT(1, branchy_classify(50));
}
