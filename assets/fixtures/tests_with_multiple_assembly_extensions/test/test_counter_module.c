/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "counter_module.h"

// Neither assembly file has a corresponding header, so Ceedling's usual naming-convention
// pickup doesn't apply -- TEST_SOURCE_FILE() is what pulls each into this executable's build.
TEST_SOURCE_FILE("asm_helper_lower.s")
TEST_SOURCE_FILE("asm_helper_upper.S")

void setUp(void)
{
}

void tearDown(void)
{
}

void test_GetValue_should_return_expected_constant(void)
{
  TEST_ASSERT_EQUAL(42, CounterModule_GetValue());
}
