/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "IntrinsicsWrapper.h"
#ifdef __ICCARM__
#include <intrinsics.h>
#endif

void Interrupt_Enable(void)
{
#ifdef __ICCARM__
  __enable_interrupt();
#endif
}

void Interrupt_Disable(void)
{
#ifdef __ICCARM__
  __disable_interrupt();
#endif
}
