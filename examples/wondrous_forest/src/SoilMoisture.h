/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef SOIL_MOISTURE_H
#define SOIL_MOISTURE_H

#include "Types.h"

void  SoilMoisture_Init(void);
bool  SoilMoisture_Sample(void);
uint8 SoilMoisture_GetPercent(void);
bool  SoilMoisture_IsDry(void);
uint8 SoilMoisture_GetSampleCount(void);

#endif /* SOIL_MOISTURE_H */
