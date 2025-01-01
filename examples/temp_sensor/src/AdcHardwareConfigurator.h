/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _ADCHARDWARECONFIGURATOR_H
#define _ADCHARDWARECONFIGURATOR_H

#include "Types.h"

void Adc_Reset(void);
void Adc_ConfigureMode(void);
void Adc_EnableTemperatureChannel(void);

#endif // _ADCHARDWARECONFIGURATOR_H
