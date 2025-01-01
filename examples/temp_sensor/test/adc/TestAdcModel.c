/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "AdcModel.h"
#include "MockTaskScheduler.h"
#include "MockTemperatureCalculator.h"
#include "MockTemperatureFilter.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testDoGetSampleShouldReturn_FALSE_WhenTaskSchedulerReturns_FALSE(void)
{
  TaskScheduler_DoAdc_ExpectAndReturn(FALSE);
  TEST_ASSERT_FALSE(AdcModel_DoGetSample());
}

void testDoGetSampleShouldReturn_TRUE_WhenTaskSchedulerReturns_TRUE(void)
{
  TaskScheduler_DoAdc_ExpectAndReturn(TRUE);
  TEST_ASSERT_TRUE(AdcModel_DoGetSample());
}

void testProcessInputShouldDelegateToTemperatureCalculatorAndPassResultToFilter(void)
{
  TemperatureCalculator_Calculate_ExpectAndReturn(21473, 23.5f);
  TemperatureFilter_ProcessInput_Expect(23.5f);
  AdcModel_ProcessInput(21473);
}
