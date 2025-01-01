/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "adc_hardware_configurator.h"

#ifdef SPECIFIC_CONFIG
void Adc_ResetSpec(void)
{
}
#elif defined(STANDARD_CONFIG)
void Adc_Reset(void)
{
}
#endif
