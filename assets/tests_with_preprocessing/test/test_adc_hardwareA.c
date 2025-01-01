/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "adc_hardwareA.h"
#ifdef PREPROCESSING_TESTS
#include "mock_adc_hardware_configuratorA.h"
#endif

void setUp(void)
{
}

void tearDown(void)
{
}

#ifdef PREPROCESSING_TESTS
void test_init_should_call_adc_reset(void)
{
  Adc_Reset_Expect();

  AdcHardware_Init();
}
#endif

#ifndef PREPROCESSING_TESTS
void test_caseA_should_fail(void)
{
  TEST_FAIL_MESSAGE("Intentional failure");
}

void test_caseB_should_fail(void)
{
  TEST_FAIL_MESSAGE("Intentional failure");
}
#endif