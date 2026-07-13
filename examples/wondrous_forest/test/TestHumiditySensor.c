/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Tests the private static inline HumiditySensor__ClampPercent() and
 * private static HumiditySensor__RawToPercent() directly, while also
 * driving state through the public API. SensorHal is mocked traditionally.
 * Uses PARTIAL_LOCAL_VAR() to access the function-scoped static s_rolling_sum
 * inside HumiditySensor_Sample(). */

#include "unity.h"
#include "ceedling.h"
#include "MockSensorHal.h"

#include TEST_PARTIAL_ALL_MODULE(HumiditySensor)

#include "Types.h"

void setUp(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_HUMIDITY);
    HumiditySensor_Init();
}

void tearDown(void)
{
}

void test_ClampPercent_BelowMinClampsToZero(void)
{
    TEST_ASSERT_EQUAL_UINT8(0u, HumiditySensor__ClampPercent(-1));
    TEST_ASSERT_EQUAL_UINT8(0u, HumiditySensor__ClampPercent(-100));
}

void test_ClampPercent_AboveMaxClampsTo100(void)
{
    TEST_ASSERT_EQUAL_UINT8(100u, HumiditySensor__ClampPercent(101));
    TEST_ASSERT_EQUAL_UINT8(100u, HumiditySensor__ClampPercent(200));
}

void test_ClampPercent_WithinRangePassesThrough(void)
{
    TEST_ASSERT_EQUAL_UINT8(0u,   HumiditySensor__ClampPercent(0));
    TEST_ASSERT_EQUAL_UINT8(50u,  HumiditySensor__ClampPercent(50));
    TEST_ASSERT_EQUAL_UINT8(100u, HumiditySensor__ClampPercent(100));
}

void test_RawToPercent_ZeroCountsGivesZeroPercent(void)
{
    TEST_ASSERT_EQUAL_UINT8(0u, HumiditySensor__RawToPercent(0u));
}

void test_RawToPercent_FullScaleGives100Percent(void)
{
    TEST_ASSERT_EQUAL_UINT8(100u, HumiditySensor__RawToPercent(4095u));
}

void test_RawToPercent_MidScaleGivesApproximately50Percent(void)
{
    /* (2048 * 100) / 4095 = 50 */
    TEST_ASSERT_UINT8_WITHIN(2u, 50u, HumiditySensor__RawToPercent(2048u));
}

void test_RollingSum_AccumulatesAcrossSamples(void)
{
    /* Delta-based assertion: robust against accumulated state from previous tests
     * since s_rolling_sum is a function-scoped static that persists. */
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_HUMIDITY, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_HUMIDITY, 2048u); /* ~= 50% */
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_HUMIDITY);
    HumiditySensor_Sample();
    uint32 sum_after_first = PARTIAL_LOCAL_VAR(HumiditySensor_Sample, s_rolling_sum);

    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_HUMIDITY, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_HUMIDITY, 4095u); /* 100% */
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_HUMIDITY);
    HumiditySensor_Sample();
    uint32 sum_after_second = PARTIAL_LOCAL_VAR(HumiditySensor_Sample, s_rolling_sum);

    TEST_ASSERT_EQUAL_UINT32(sum_after_first + 100u, sum_after_second);
}
