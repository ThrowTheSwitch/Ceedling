/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _TEMPERATUREFILTER_H
#define _TEMPERATUREFILTER_H

#include "Types.h"

void TemperatureFilter_Init(void);
float TemperatureFilter_GetTemperatureInCelcius(void);
void TemperatureFilter_ProcessInput(float temperature);

#endif // _TEMPERATUREFILTER_H
