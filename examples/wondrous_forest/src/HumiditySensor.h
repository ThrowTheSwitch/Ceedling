/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef HUMIDITY_SENSOR_H
#define HUMIDITY_SENSOR_H

#include "Types.h"

void  HumiditySensor_Init(void);
bool  HumiditySensor_Sample(void);
uint8 HumiditySensor_GetPercent(void);

#endif /* HUMIDITY_SENSOR_H */
