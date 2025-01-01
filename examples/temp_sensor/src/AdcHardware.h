/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _ADCHARDWARE_H
#define _ADCHARDWARE_H

#include "Types.h"

void AdcHardware_Init(void);
void AdcHardware_StartConversion(void);
bool AdcHardware_GetSampleComplete(void);
uint16 AdcHardware_GetSample(void);

#endif // _ADCHARDWARE_H
