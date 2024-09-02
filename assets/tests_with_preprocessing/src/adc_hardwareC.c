/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "adc_hardwareC.h"
#include "adc_hardware_configuratorC.h"

void AdcHardware_Init(void)
{
  Adc_Reset();
}