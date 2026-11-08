/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "RainTipIsr.h"
#include "RainGauge.h"

uint32 g_rain_tip_count = 0u;

void RainTipIsr_Handler(void)
{
    g_rain_tip_count++;
}
