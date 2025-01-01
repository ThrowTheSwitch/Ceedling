/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "adc_hardwareB.h"
#include "adc_hardware_configuratorB.h"

void AdcHardware_Init(void)
{
  Adc_Reset();
}
