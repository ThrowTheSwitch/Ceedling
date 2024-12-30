/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "adc_hardwareB.h"
#include "mock_adc_hardware_configuratorB.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_init_should_call_adc_reset(void)
{
  Adc_Reset_Expect();

  AdcHardware_Init();
}
