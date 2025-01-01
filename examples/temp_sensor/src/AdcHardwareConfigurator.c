/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "AdcHardwareConfigurator.h"
#include "ModelConfig.h"

void Adc_Reset(void)
{
  AT91C_BASE_ADC->ADC_CR = AT91C_ADC_SWRST;
}

void Adc_ConfigureMode(void)
{
  AT91C_BASE_ADC->ADC_MR = (((uint32)11) << 8) | (((uint32)4) << 16);
}

void Adc_EnableTemperatureChannel(void)
{
  AT91C_BASE_ADC->ADC_CHER = 0x10;
}
