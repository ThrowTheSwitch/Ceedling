/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef SENSOR_HAL_H
#define SENSOR_HAL_H

#include "Types.h"

void   SensorHal_Init(void);
uint16 SensorHal_ReadChannel(SensorChannel_t channel);
bool   SensorHal_IsChannelReady(SensorChannel_t channel);
void   SensorHal_StartConversion(SensorChannel_t channel);
uint32 SensorHal_GetTimestampMs(void);

#endif /* SENSOR_HAL_H */
