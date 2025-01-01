/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _TASKSCHEDULER_H
#define _TASKSCHEDULER_H

#include "Types.h"

void TaskScheduler_Init(void);
void TaskScheduler_Update(uint32 time);
bool TaskScheduler_DoUsart(void);
bool TaskScheduler_DoAdc(void);

#endif // _TASKSCHEDULER_H
