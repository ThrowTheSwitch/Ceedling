/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "adc_hardwareA.h"
#include "adc_hardware_configuratorA.h"

void AdcHardware_Init(void)
{
  // Reusing outer test file preprocessing symbol to prevent linking failure
  #ifdef PREPROCESSING_TESTS
  Adc_Reset();
  #endif
}
