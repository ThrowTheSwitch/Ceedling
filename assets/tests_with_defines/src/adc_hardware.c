/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "adc_hardware.h"
#include "adc_hardware_configurator.h"

void AdcHardware_Init(void)
{
  #ifdef SPECIFIC_CONFIG
  Adc_ResetSpec();
  #elif defined(STANDARD_CONFIG)
  Adc_Reset();
  #endif
}
