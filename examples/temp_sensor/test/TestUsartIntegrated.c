/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "UsartConductor.h"
#include "UsartModel.h"
#include "UsartHardware.h"
#include "ModelConfig.h"
#include "MockTaskScheduler.h"
#include "MockUsartConfigurator.h"
#include "MockUsartPutChar.h"
#include "MockTemperatureFilter.h"
#include "calculators/MockUsartBaudRateRegisterCalculator.h" // Proves we can find a mock even with a path
#include <string.h>

/* NOTE: we probably wouldn't actually perform this test on our own projects
  but it's a good example of testing the same module(s) from multiple test
  files, and therefore we like having it in this example. 
*/

#ifndef TEST_USART_INTEGRATED_STRING
#define TEST_USART_INTEGRATED_STRING "THIS WILL FAIL"
#endif

void setUp(void)
{
}

void tearDown(void)
{
}

void testShouldInitializeHardwareWhenInitCalled(void)
{
  size_t i;
  const char* test_str = TEST_USART_INTEGRATED_STRING;

  UsartModel_CalculateBaudRateRegisterSetting_ExpectAndReturn(MASTER_CLOCK, USART0_BAUDRATE, 4);
  Usart_ConfigureUsartIO_Expect();
  Usart_EnablePeripheralClock_Expect();
  Usart_Reset_Expect();
  Usart_ConfigureMode_Expect();
  Usart_SetBaudRateRegister_Expect(4);
  Usart_Enable_Expect();
  for (i=0; i < strlen(test_str); i++)
  {
    Usart_PutChar_Expect(test_str[i]);
  }

  UsartConductor_Init();
}

void testRunShouldNotDoAnythingIfSchedulerSaysItIsNotTimeYet(void)
{
  TaskScheduler_DoUsart_ExpectAndReturn(FALSE);

  UsartConductor_Run();
}
