/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "MockExecutor.h"
#include "Main.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testMainShouldCallExecutorInitAndContinueToCallExecutorRunUntilHalted(void)
{
  Executor_Init_Expect();
  Executor_Run_ExpectAndReturn(TRUE);
  Executor_Run_ExpectAndReturn(TRUE);
  Executor_Run_ExpectAndReturn(TRUE);
  Executor_Run_ExpectAndReturn(TRUE);
  Executor_Run_ExpectAndReturn(FALSE);
  
  AppMain();
}
