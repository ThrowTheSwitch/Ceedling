/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "HumiditySensor.h"
#include "SensorHal.h"

static uint8 s_current_percent;
static uint8 s_sample_count;
static bool  s_initialized;

static inline uint8 HumiditySensor__ClampPercent(int32 value)
{
    if (value < (int32)HUMIDITY_PERCENT_MIN) { return (uint8)HUMIDITY_PERCENT_MIN; }
    if (value > (int32)HUMIDITY_PERCENT_MAX) { return (uint8)HUMIDITY_PERCENT_MAX; }
    return (uint8)value;
}

static uint8 HumiditySensor__RawToPercent(uint16 raw_counts)
{
    return HumiditySensor__ClampPercent((int32)(((uint32)raw_counts * 100ul) / (uint32)ADC_MAX_COUNTS));
}

void HumiditySensor_Init(void)
{
    s_current_percent = 0u;
    s_sample_count    = 0u;
    s_initialized     = true;
    SensorHal_StartConversion(SENSOR_CHANNEL_HUMIDITY);
}

bool HumiditySensor_Sample(void)
{
    /* Function-scoped static: rolling sum for average. Exposed via Partials as
     * partial_HumiditySensor_Sample_s_rolling_sum. */
    static uint32 s_rolling_sum = 0u;

    if (!s_initialized)                                      { return false; }
    if (!SensorHal_IsChannelReady(SENSOR_CHANNEL_HUMIDITY)) { return false; }

    uint16 raw        = SensorHal_ReadChannel(SENSOR_CHANNEL_HUMIDITY);
    s_current_percent = HumiditySensor__RawToPercent(raw);
    s_rolling_sum    += (uint32)s_current_percent;
    s_sample_count++;

    SensorHal_StartConversion(SENSOR_CHANNEL_HUMIDITY);
    return true;
}

uint8 HumiditySensor_GetPercent(void)
{
    return s_current_percent;
}
