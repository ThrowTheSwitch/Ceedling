/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _TIMERINTERRUPTCONFIGURATOR_H
#define _TIMERINTERRUPTCONFIGURATOR_H

#include "Types.h"

#define TIMER0_ID_MASK (((uint32)0x1) << AT91C_ID_TC0)

void Timer_DisableInterrupt(void);
void Timer_ResetSystemTime(void);
void Timer_ConfigureInterrupt(void);
void Timer_EnableInterrupt(void);

#endif // _TIMERINTERRUPTCONFIGURATOR_H
