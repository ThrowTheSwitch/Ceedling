/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TimerModel.h"
#include "TaskScheduler.h"

void TimerModel_UpdateTime(uint32 systemTime)
{
  TaskScheduler_Update(systemTime);
}

