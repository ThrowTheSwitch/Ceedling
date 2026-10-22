/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * End-to-end proof that the generated Partial implementation file for sensor.c
 * carries each of its three same-basename config.h #includes with its own real,
 * disambiguating path -- a nested subdirectory (drivers/config.h, app/config.h)
 * and a `..`-relative one (../shared/config.h, resolved to src/shared/config.h).
 * See sensor.c for why any two of the three colliding on a bare "config.h"
 * guarantees a compile error rather than merely a wrong runtime value. */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(sensor)

void setUp(void)
{
}

void tearDown(void)
{
}

void test_ReadScaled_ReturnsExpectedValue(void)
{
    TEST_ASSERT_EQUAL_INT(42, Sensor_ReadScaled());
}
