/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _TIMERINTERRUPTHANDLER_H
#define _TIMERINTERRUPTHANDLER_H

#include "Types.h"

void Timer_SetSystemTime(uint32 time);
uint32 Timer_GetSystemTime(void);
void Timer_InterruptHandler(void);

#endif // _TIMERINTERRUPTHANDLER_H
