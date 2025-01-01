/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _ADCCONDUCTOR_H
#define _ADCCONDUCTOR_H

#include "Types.h"

void AdcConductor_Init(void);
void AdcConductor_Run(void);

bool AdcConductor_JustHereToTest(void);
bool AdcConductor_AlsoHereToTest(void);
bool AdcConductor_YetAnotherTest(void);

#endif // _ADCCONDUCTOR_H
