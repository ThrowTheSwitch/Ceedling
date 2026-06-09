/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "LightSensor.h"
#include "SensorHal.h"

static uint32 s_lux_value;
static uint32 s_nighttime_threshold_lux;

/* Full-scale 4095 counts = 100 000 lux. */
PRIVATE uint32 LightSensor__ConvertRawToLux(uint16 raw_counts)
{
    return ((uint32)raw_counts * 100000ul) / (uint32)ADC_MAX_COUNTS;
}

PRIVATE_INLINE bool LightSensor__IsNighttime(uint32 lux)
{
    return lux < s_nighttime_threshold_lux;
}

void LightSensor_Init(uint32 nighttime_threshold_lux)
{
    s_lux_value               = 0u;
    s_nighttime_threshold_lux = nighttime_threshold_lux;
    SensorHal_StartConversion(SENSOR_CHANNEL_LIGHT);
}

bool LightSensor_Sample(void)
{
    if (!SensorHal_IsChannelReady(SENSOR_CHANNEL_LIGHT)) { return false; }

    uint16 raw  = SensorHal_ReadChannel(SENSOR_CHANNEL_LIGHT);
    s_lux_value = LightSensor__ConvertRawToLux(raw);
    SensorHal_StartConversion(SENSOR_CHANNEL_LIGHT);
    return true;
}

uint32 LightSensor_GetLux(void)
{
    return s_lux_value;
}

bool LightSensor_IsNighttime(void)
{
    return LightSensor__IsNighttime(s_lux_value);
}
