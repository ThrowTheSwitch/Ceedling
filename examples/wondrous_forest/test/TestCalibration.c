/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_PRIVATE_MODULE_AT
 * Two sensors each carry their own Calibration module, so the module name alone
 * names two files. Each directive adds the directory that tells them apart, and
 * each Partial carries only its own module's private clamp. */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_PRIVATE_MODULE_AT(sensors/soil, Calibration)
#include TEST_PARTIAL_PRIVATE_MODULE_AT(sensors/light, Calibration)

void setUp(void) {}
void tearDown(void) {}

/* Each clamp has its own ceiling, so the same input gives each module a
 * different answer. A Partial built from the wrong module would still compile
 * and link -- it would simply return the other sensor's value. */
void test_SoilClampCeilingIsSaturationPercentage(void)
{
  TEST_ASSERT_EQUAL_INT(100, Soil__Clamp(150));
}

void test_LightClampCeilingIsAdcFullScale(void)
{
  TEST_ASSERT_EQUAL_INT(150, Light__Clamp(150));
}

void test_ClampsPassThroughValuesWithinTheirOwnRange(void)
{
  TEST_ASSERT_EQUAL_INT(42, Soil__Clamp(42));
  TEST_ASSERT_EQUAL_INT(42, Light__Clamp(42));
}
