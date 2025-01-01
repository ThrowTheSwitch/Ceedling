/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TimerConductor.h"
#include "TimerModel.h"
#include "TimerHardware.h"
#include "TimerInterruptHandler.h"

void TimerConductor_Init(void)
{
  TimerHardware_Init();
}

void TimerConductor_Run(void)
{
  TimerModel_UpdateTime(Timer_GetSystemTime());
}
