/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef LIGHT_SENSOR_H
#define LIGHT_SENSOR_H

#include "Types.h"

typedef enum
{
    LIGHT_LEVEL_DARK   = 0,
    LIGHT_LEVEL_DIM    = 1,
    LIGHT_LEVEL_BRIGHT = 2
} LightLevel_t;

void         LightSensor_Init(uint32 nighttime_threshold_lux);
bool         LightSensor_Sample(void);
uint32       LightSensor_GetLux(void);
bool         LightSensor_IsNighttime(void);
LightLevel_t LightSensor_GetLightLevel(void);

#endif /* LIGHT_SENSOR_H */
