/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_PUBLIC_MODULE + MOCK_PARTIAL_PRIVATE_MODULE
 * Tests the public interface (LightSensor_Sample, GetLux, IsNighttime)
 * while mocking the private helpers LightSensor__ConvertRawToLux() and
 * LightSensor__IsNighttime(). SensorHal is mocked traditionally.
 * This demonstrates testing public behavior while isolating private logic. */

#include "unity.h"
#include "ceedling.h"
#include "MockSensorHal.h"

#include TEST_PARTIAL_PUBLIC_MODULE(LightSensor)
#include MOCK_PARTIAL_PRIVATE_MODULE(LightSensor)

#include "Types.h"

void setUp(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_LIGHT);
    LightSensor_Init(500u);
}

void tearDown(void)
{
}

void test_GetLux_ReturnsZeroBeforeAnySample(void)
{
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_LIGHT);
    LightSensor_Init(1000u);
    TEST_ASSERT_EQUAL_UINT32(0u, LightSensor_GetLux());
}

void test_Sample_ReturnsFalseWhenChannelNotReady(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, false);
    TEST_ASSERT_FALSE(LightSensor_Sample());
}

void test_Sample_CallsConvertHelperAndStoresResult(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, 2000u);
    LightSensor__ConvertRawToLux_ExpectAndReturn(2000u, 48840u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_LIGHT);

    TEST_ASSERT_TRUE(LightSensor_Sample());
    TEST_ASSERT_EQUAL_UINT32(48840u, LightSensor_GetLux());
}

void test_IsNighttime_ReturnsTrueWhenPrivateHelperReturnsTrue(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, 10u);
    LightSensor__ConvertRawToLux_ExpectAndReturn(10u, 244u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_LIGHT);
    LightSensor_Sample();

    LightSensor__IsNighttime_ExpectAndReturn(244u, true);
    TEST_ASSERT_TRUE(LightSensor_IsNighttime());
}

void test_IsNighttime_ReturnsFalseWhenPrivateHelperReturnsFalse(void)
{
    SensorHal_IsChannelReady_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, true);
    SensorHal_ReadChannel_ExpectAndReturn(SENSOR_CHANNEL_LIGHT, 3000u);
    LightSensor__ConvertRawToLux_ExpectAndReturn(3000u, 73260u);
    SensorHal_StartConversion_Expect(SENSOR_CHANNEL_LIGHT);
    LightSensor_Sample();

    LightSensor__IsNighttime_ExpectAndReturn(73260u, false);
    TEST_ASSERT_FALSE(LightSensor_IsNighttime());
}
