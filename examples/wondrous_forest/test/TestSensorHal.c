/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Traditional test - no Partials needed.
 * SensorHal has no private static functions; it is a thin hardware wrapper.
 * The #ifdef TEST guards in SensorHal.c substitute zero-initialized static
 * arrays for memory-mapped registers, making this code safe to run on a host.
 * Tests verify the observable behavior given that known initial register state. */

#include "unity.h"
#include "Types.h"
#include "SensorHal.h"

void setUp(void)
{
    SensorHal_Init();
}

void tearDown(void)
{
}

void test_IsChannelReady_ReturnsFalseWhenStatusRegisterClear(void)
{
    /* In test builds, status array initializes to 0 (not ready). */
    TEST_ASSERT_FALSE(SensorHal_IsChannelReady(SENSOR_CHANNEL_TEMP));
    TEST_ASSERT_FALSE(SensorHal_IsChannelReady(SENSOR_CHANNEL_HUMIDITY));
}

void test_ReadChannel_ReturnsZeroWhenDataRegisterClear(void)
{
    TEST_ASSERT_EQUAL_UINT16(0u, SensorHal_ReadChannel(SENSOR_CHANNEL_TEMP));
}

void test_ReadChannel_AlwaysWithinAdcRange(void)
{
    uint16 val = SensorHal_ReadChannel(SENSOR_CHANNEL_LIGHT);
    TEST_ASSERT_LESS_OR_EQUAL_UINT16(ADC_MAX_COUNTS, val);
}

void test_StartConversion_IsCallableForAllChannels(void)
{
    SensorHal_StartConversion(SENSOR_CHANNEL_TEMP);
    SensorHal_StartConversion(SENSOR_CHANNEL_HUMIDITY);
    SensorHal_StartConversion(SENSOR_CHANNEL_LIGHT);
    SensorHal_StartConversion(SENSOR_CHANNEL_SOIL);
    TEST_PASS();
}

void test_GetTimestampMs_ReturnsZeroWhenTickRegisterClear(void)
{
    /* In test builds, the sys tick register substitute initializes to 0. */
    TEST_ASSERT_EQUAL_UINT32(0u, SensorHal_GetTimestampMs());
}
