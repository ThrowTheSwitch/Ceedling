/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Tests both public functions AND the private static helpers
 * TemperatureSensor__RawToMilliCelsius() and TemperatureSensor__IsInRange().
 * Also accesses the file-scoped static s_calibration_offset directly.
 * SensorHal is mocked traditionally since it has no private statics. */

#include "unity.h"
#include "ceedling.h"
#include "MockSensorHal.h"

#include TEST_PARTIAL_ALL_MODULE(TemperatureSensor)

#include "Types.h"

void setUp(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_TEMP);
    TemperatureSensor_Init(0.0f);
}

void tearDown(void)
{
}

void test_RawToMilliCelsius_ZeroCountsGivesZero(void)
{
    TEST_ASSERT_EQUAL_INT32(0, TemperatureSensor__RawToMilliCelsius(0u));
}

void test_RawToMilliCelsius_FullScaleGives85000(void)
{
    TEST_ASSERT_EQUAL_INT32(85000, TemperatureSensor__RawToMilliCelsius(4095u));
}

void test_RawToMilliCelsius_MidScaleGivesApproximately42500(void)
{
    /* (2048 * 85000) / 4095 = 42502 */
    TEST_ASSERT_INT32_WITHIN(100, 42500, TemperatureSensor__RawToMilliCelsius(2048u));
}

void test_IsInRange_ValidTemperaturesReturnTrue(void)
{
    TEST_ASSERT_TRUE(TemperatureSensor__IsInRange(25000));
    TEST_ASSERT_TRUE(TemperatureSensor__IsInRange(0));
    TEST_ASSERT_TRUE(TemperatureSensor__IsInRange(85000));
    TEST_ASSERT_TRUE(TemperatureSensor__IsInRange(-40000));
}

void test_IsInRange_OutOfRangeReturnsFalse(void)
{
    TEST_ASSERT_FALSE(TemperatureSensor__IsInRange(85001));
    TEST_ASSERT_FALSE(TemperatureSensor__IsInRange(-40001));
}

void test_CalibrationOffsetIsStoredOnInit(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_TEMP);
    TemperatureSensor_Init(2.5f);
    /* s_calibration_offset is a file-scoped static exposed as extern by Partials */
    TEST_ASSERT_FLOAT_WITHIN(0.001f, 2.5f, s_calibration_offset);
}

void test_Sample_ReturnsFalseWhenChannelNotReady(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_TEMP, false);
    TEST_ASSERT_FALSE(TemperatureSensor_Sample());
}

void test_Sample_ReturnsTrueAndStoresReadingWhenReady(void)
{
    /* 1638 counts: (1638 * 85000) / 4095 ~= 34000 milli-C (34 C), in range */
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_TEMP, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_TEMP, 1638u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_TEMP);

    TEST_ASSERT_TRUE(TemperatureSensor_Sample());
    TEST_ASSERT_TRUE(TemperatureSensor_IsValid());
    TEST_ASSERT_INT32_WITHIN(100, 34000, TemperatureSensor_GetMilliCelsius());
}

void test_CalibrationOffsetShiftsReading(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_TEMP);
    TemperatureSensor_Init(1.0f);

    /* 2048 counts ~= 42502 milli-C; with +1.0 C offset -> ~= 43502 */
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_TEMP, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_TEMP, 2048u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_TEMP);

    TemperatureSensor_Sample();
    TEST_ASSERT_INT32_WITHIN(200, 43502, TemperatureSensor_GetMilliCelsius());
}
