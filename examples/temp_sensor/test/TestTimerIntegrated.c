/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "TimerConductor.h"
#include "TimerHardware.h"
#include "TimerModel.h"
#include "MockTimerConfigurator.h"
#include "MockTimerInterruptHandler.h"
#include "MockTaskScheduler.h"

/* NOTES:
  - We probably wouldn't perform this test on our own projects,
    but it's a good example of testing the same module(s) from multiple test
    files, and therefore we like having it in this example.
  - That said, it is appropriate in some testing scenarios to test
    multiple source files together (e.g. protocol handling or memory management).
    Typically, unit tests isolate a single source module.
*/

void setUp(void)
{
}

void tearDown(void)
{
}

void testInitShouldCallHardwareInit(void)
{
  Timer_EnablePeripheralClocks_Expect();
  Timer_Reset_Expect();
  Timer_ConfigureMode_Expect();
  Timer_ConfigurePeriod_Expect();
  Timer_EnableOutputPin_Expect();
  Timer_Enable_Expect();
  Timer_ConfigureInterruptHandler_Expect();
  Timer_Start_Expect();

  TimerConductor_Init();
}

void testRunShouldGetSystemTimeAndPassOnToModelForEventScheduling(void)
{
  Timer_GetSystemTime_ExpectAndReturn(1230);
  TaskScheduler_Update_Expect(1230);
  TimerConductor_Run();

  Timer_GetSystemTime_ExpectAndReturn(837460);
  TaskScheduler_Update_Expect(837460);
  TimerConductor_Run();
}
