/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

/* Vendor-header-style static inline register accessor -- the same pattern that
 * makes a real hardware header need Partial mocking instead of ordinary mocking,
 * since there is no separate .c file to exclude from a test build and swap for a
 * mock's .o at link time. The real body here stands in for what would otherwise
 * be a direct, unsafe-off-target memory-mapped register read: it always returns
 * the same obviously-wrong sentinel, so a test can tell whether this real body
 * ran (Partial mocking failed to intercept the call) instead of its mock. */
static inline uint16 SensorHal_RawStatusRegister(SensorChannel_t channel)
{
    (void)channel;
    return 0xDEADu;
}

#endif /* SENSOR_HAL_H */
