/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef LIGHT_SENSOR_H
#define LIGHT_SENSOR_H

#include "Types.h"

void   LightSensor_Init(uint32 nighttime_threshold_lux);
bool   LightSensor_Sample(void);
uint32 LightSensor_GetLux(void);
bool   LightSensor_IsNighttime(void);

#endif /* LIGHT_SENSOR_H */
