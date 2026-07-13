/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "SoilMoisture.h"
#include "SensorHal.h"

#define SOIL_DRY_THRESHOLD_PERCENT (20u)

static uint8 s_moisture_percent;
static uint8 s_total_sample_count;

/* Resistive sensor: lower counts = wetter; mapping is inverted. */
static uint8 SoilMoisture__RawToPercent(uint16 raw_counts)
{
    uint32 inverted = (uint32)ADC_MAX_COUNTS - (uint32)raw_counts;
    return (uint8)((inverted * 100ul) / (uint32)ADC_MAX_COUNTS);
}

void SoilMoisture_Init(void)
{
    s_moisture_percent   = 0u;
    s_total_sample_count = 0u;
    SensorHal_StartConversion(SENSOR_CHANNEL_SOIL);
}

bool SoilMoisture_Sample(void)
{
    /* Function-scoped static: accumulates raw ADC totals for drift detection.
     * Exposed via Partials as partial_SoilMoisture_Sample_s_raw_accumulator. */
    static uint32 s_raw_accumulator = 0u;

    if (!SensorHal_IsChannelReady(SENSOR_CHANNEL_SOIL)) { return false; }

    uint16 raw         = SensorHal_ReadChannel(SENSOR_CHANNEL_SOIL);
    s_raw_accumulator += (uint32)raw;
    s_moisture_percent = SoilMoisture__RawToPercent(raw);
    s_total_sample_count++;

    SensorHal_StartConversion(SENSOR_CHANNEL_SOIL);
    return true;
}

uint8 SoilMoisture_GetPercent(void)
{
    return s_moisture_percent;
}

bool SoilMoisture_IsDry(void)
{
    return s_moisture_percent < SOIL_DRY_THRESHOLD_PERCENT;
}

uint8 SoilMoisture_GetSampleCount(void)
{
    return s_total_sample_count;
}
