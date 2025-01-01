/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "TimerConductor.h"
#include "MockTimerHardware.h"
#include "MockTimerModel.h"
#include "MockTimerInterruptHandler.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testInitShouldCallHardwareInit(void)
{
  TimerHardware_Init_Expect();

  TimerConductor_Init();
}

void testRunShouldGetSystemTimeAndPassOnToModelForEventScheduling(void)
{
  Timer_GetSystemTime_ExpectAndReturn(1230);
  TimerModel_UpdateTime_Expect(1230);
  TimerConductor_Run();

  Timer_GetSystemTime_ExpectAndReturn(837460);
  TimerModel_UpdateTime_Expect(837460);
  TimerConductor_Run();
}
