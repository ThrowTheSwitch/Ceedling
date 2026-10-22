/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "LightSensor.h"
#include "SensorHal.h"

static uint32       s_lux_value;
static uint32       s_nighttime_threshold_lux;
static LightLevel_t s_light_level;

/* Full-scale 4095 counts = 100 000 lux. */
PRIVATE uint32 LightSensor__ConvertRawToLux(uint16 raw_counts)
{
    return ((uint32)raw_counts * 100000ul) / (uint32)ADC_MAX_COUNTS;
}

PRIVATE_INLINE bool LightSensor__IsNighttime(uint32 lux)
{
    return lux < s_nighttime_threshold_lux;
}

/* Three-way classification of a lux reading, coarser than the raw value itself
 * and handy for display or logging without exposing the underlying threshold math. */
PRIVATE LightLevel_t LightSensor__ClassifyLux(uint32 lux)
{
    if (lux < 50u)   { return LIGHT_LEVEL_DARK; }
    if (lux < 5000u) { return LIGHT_LEVEL_DIM; }
    return LIGHT_LEVEL_BRIGHT;
}

void LightSensor_Init(uint32 nighttime_threshold_lux)
{
    s_lux_value               = 0u;
    s_nighttime_threshold_lux = nighttime_threshold_lux;
    s_light_level             = LIGHT_LEVEL_DARK;
    SensorHal_StartConversion(SENSOR_CHANNEL_LIGHT);
}

bool LightSensor_Sample(void)
{
    if (!SensorHal_IsChannelReady(SENSOR_CHANNEL_LIGHT)) { return false; }

    uint16 raw    = SensorHal_ReadChannel(SENSOR_CHANNEL_LIGHT);
    s_lux_value   = LightSensor__ConvertRawToLux(raw);
    s_light_level = LightSensor__ClassifyLux(s_lux_value);
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

LightLevel_t LightSensor_GetLightLevel(void)
{
    return s_light_level;
}
