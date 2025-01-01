/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _ADCMODEL_H
#define _ADCMODEL_H

#include "Types.h"

bool AdcModel_DoGetSample(void);
void AdcModel_ProcessInput(uint16 millivolts);

bool AdcModel_DoNothingExceptTestASpecialType(EXAMPLE_STRUCT_T ExampleStruct);
bool AdModel_DoNothingExceptTestPointers(uint32* pExample);
EXAMPLE_STRUCT_T AdcModel_DoNothingExceptReturnASpecialType(void);

#endif // _ADCMODEL_H
