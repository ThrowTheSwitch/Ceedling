/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TimerInterruptHandler.h"
#include "TimerInterruptConfigurator.h"

static uint32 systemTime;

void Timer_SetSystemTime(uint32 time)
{
  systemTime = time;
}

uint32 Timer_GetSystemTime(void)
{
  return systemTime;
}

void Timer_InterruptHandler(void)
{
  uint32 status = AT91C_BASE_TC0->TC_SR;
  if (status & AT91C_TC_CPCS)
  {
    systemTime += 10;
  }
}

