/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include "UsartBaudRateRegisterCalculator.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void testCalculateBaudRateRegisterSettingShouldCalculateRegisterSettingAppropriately(void)
{
  // BaudRate = MCK / (CD x 16) - per datasheet section 30.6.1.2 "Baud Rate Calculation Example"
  TEST_ASSERT_EQUAL_INT(26, UsartModel_CalculateBaudRateRegisterSetting(48000000, 115200));
  TEST_ASSERT_EQUAL_INT(6,  UsartModel_CalculateBaudRateRegisterSetting(3686400,  38400));
  TEST_ASSERT_EQUAL_INT(23, UsartModel_CalculateBaudRateRegisterSetting(14318180, 38400));
  TEST_ASSERT_EQUAL_INT(20, UsartModel_CalculateBaudRateRegisterSetting(12000000, 38400));
  TEST_ASSERT_EQUAL_INT(13, UsartModel_CalculateBaudRateRegisterSetting(12000000, 56800));
}
