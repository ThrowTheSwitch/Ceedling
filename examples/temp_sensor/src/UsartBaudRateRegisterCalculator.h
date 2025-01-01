/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _USARTBAUDRATEREGISTERCALCULATOR_H
#define _USARTBAUDRATEREGISTERCALCULATOR_H

#include "Types.h"

uint8 UsartModel_CalculateBaudRateRegisterSetting(uint32 masterClock, uint32 baudRate);

#endif // _USARTBAUDRATEREGISTERCALCULATOR_H
