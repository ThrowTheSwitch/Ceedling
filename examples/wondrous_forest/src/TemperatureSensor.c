/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TemperatureSensor.h"
#include "SensorHal.h"

static float s_calibration_offset;
static int32 s_last_milli_celsius;
static bool  s_reading_valid;

/* Linearized approximation: full-scale 4095 counts maps 0 C to 85 C. */
static int32 TemperatureSensor__RawToMilliCelsius(uint16 raw_counts)
{
    return (int32)(((uint32)raw_counts * 85000ul) / (uint32)ADC_MAX_COUNTS);
}

static bool TemperatureSensor__IsInRange(int32 milli_c)
{
    return (milli_c >= (int32)TEMP_CELSIUS_MIN * 1000) &&
           (milli_c <= (int32)TEMP_CELSIUS_MAX * 1000);
}

void TemperatureSensor_Init(float calibration_offset_celsius)
{
    /* Tracks re-initialization count across the lifetime of the module. */
    static uint32 s_init_count = 0u;
    s_init_count++;

    s_calibration_offset = calibration_offset_celsius;
    s_last_milli_celsius = 0;
    s_reading_valid      = false;

    SensorHal_StartConversion(SENSOR_CHANNEL_TEMP);
}

bool TemperatureSensor_Sample(void)
{
    uint16 raw;
    int32  milli_c;

    if (!SensorHal_IsChannelReady(SENSOR_CHANNEL_TEMP)) { return false; }

    raw     = SensorHal_ReadChannel(SENSOR_CHANNEL_TEMP);
    milli_c = TemperatureSensor__RawToMilliCelsius(raw);
    milli_c += (int32)(s_calibration_offset * 1000.0f);

    s_reading_valid      = TemperatureSensor__IsInRange(milli_c);
    s_last_milli_celsius = s_reading_valid ? milli_c : s_last_milli_celsius;

    SensorHal_StartConversion(SENSOR_CHANNEL_TEMP);
    return s_reading_valid;
}

int32 TemperatureSensor_GetMilliCelsius(void)
{
    return s_last_milli_celsius;
}

bool TemperatureSensor_IsValid(void)
{
    return s_reading_valid;
}
