/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef TEMPERATURE_SENSOR_H
#define TEMPERATURE_SENSOR_H

#include "Types.h"

void  TemperatureSensor_Init(float calibration_offset_celsius);
bool  TemperatureSensor_Sample(void);
int32 TemperatureSensor_GetMilliCelsius(void);
bool  TemperatureSensor_IsValid(void);

#endif /* TEMPERATURE_SENSOR_H */
