/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "UsartConductor.h"
#include "MockUsartModel.h"
#include "MockUsartHardware.h"
#include "MockTaskScheduler.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testShouldInitializeHardwareWhenInitCalled(void)
{
  UsartModel_GetBaudRateRegisterSetting_ExpectAndReturn(4);
  UsartHardware_Init_Expect(4);
  UsartModel_GetWakeupMessage_ExpectAndReturn("Hey there!");
  UsartHardware_TransmitString_Expect("Hey there!");

  UsartConductor_Init();
}

void testRunShouldNotDoAnythingIfSchedulerSaysItIsNotTimeYet(void)
{
  TaskScheduler_DoUsart_ExpectAndReturn(FALSE);

  UsartConductor_Run();
}

void testRunShouldGetCurrentTemperatureAndTransmitIfSchedulerSaysItIsTime(void)
{
  TaskScheduler_DoUsart_ExpectAndReturn(TRUE);
  UsartModel_GetFormattedTemperature_ExpectAndReturn("hey there");
  UsartHardware_TransmitString_Expect("hey there");

  UsartConductor_Run();
}
