/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "Model.h"
#include "MockTaskScheduler.h"
#include "MockTemperatureFilter.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testInitShouldCallSchedulerAndTemperatureFilterInit(void)
{
  TaskScheduler_Init_Expect();
  TemperatureFilter_Init_Expect();
  Model_Init();
}
