/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Tests private static SoilMoisture__RawToPercent() directly, while also
 * driving state through the public API. SensorHal is mocked traditionally.
 * Uses PARTIAL_LOCAL_VAR() to access and verify the function-scoped static
 * s_raw_accumulator inside SoilMoisture_Sample(). */

#include "unity.h"
#include "ceedling.h"
#include "MockSensorHal.h"

#include TEST_PARTIAL_ALL_MODULE(SoilMoisture)

#include "Types.h"

void setUp(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_SOIL);
    SoilMoisture_Init();
}

void tearDown(void)
{
}

void test_RawToPercent_ZeroCountsGives100PercentWet(void)
{
    /* 0 counts -> inverted: 4095; (4095 * 100) / 4095 = 100% */
    TEST_ASSERT_EQUAL_UINT8(100u, SoilMoisture__RawToPercent(0u));
}

void test_RawToPercent_FullScaleCountsGives0Percent(void)
{
    /* 4095 counts -> inverted: 0; 0% */
    TEST_ASSERT_EQUAL_UINT8(0u, SoilMoisture__RawToPercent(4095u));
}

void test_RawToPercent_MidScaleGivesApproximately50Percent(void)
{
    /* 2048 counts -> inverted: 2047; (2047 * 100) / 4095 ~= 50% */
    TEST_ASSERT_UINT8_WITHIN(2u, 50u, SoilMoisture__RawToPercent(2048u));
}

void test_RawToPercent_QuarterScaleGivesApproximately75Percent(void)
{
    /* 1024 counts -> inverted: 3071; (3071 * 100) / 4095 ~= 75% */
    TEST_ASSERT_UINT8_WITHIN(2u, 75u, SoilMoisture__RawToPercent(1024u));
}

void test_RawAccumulator_IncreasesWithEachSample(void)
{
    /* Delta-based: robust against accumulated state from previous tests
     * since s_raw_accumulator is a function-scoped static that persists. */
    uint32 acc_before = PARTIAL_LOCAL_VAR(SoilMoisture_Sample, s_raw_accumulator);

    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_SOIL, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_SOIL, 1000u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_SOIL);
    SoilMoisture_Sample();
    uint32 acc_after_first = PARTIAL_LOCAL_VAR(SoilMoisture_Sample, s_raw_accumulator);
    TEST_ASSERT_EQUAL_UINT32(acc_before + 1000u, acc_after_first);

    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_SOIL, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_SOIL, 2000u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_SOIL);
    SoilMoisture_Sample();
    uint32 acc_after_second = PARTIAL_LOCAL_VAR(SoilMoisture_Sample, s_raw_accumulator);
    TEST_ASSERT_EQUAL_UINT32(acc_after_first + 2000u, acc_after_second);
}

void test_IsDry_TrueWhenMoistureBelow20Percent(void)
{
    /* 3500 counts -> inverted: 595; (595 * 100) / 4095 ~= 14% -> dry */
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_SOIL, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_SOIL, 3500u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_SOIL);
    SoilMoisture_Sample();

    TEST_ASSERT_TRUE(SoilMoisture_IsDry());
}

void test_IsDry_FalseWhenMoistureAtMidScale(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_SOIL, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_SOIL, 2048u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_SOIL);
    SoilMoisture_Sample();

    TEST_ASSERT_FALSE(SoilMoisture_IsDry());
}
