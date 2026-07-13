/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE + traditional mock coexistence
 * Tests all public AND private functions: AlertManager__FindFreeSlot(),
 * AlertManager__RaiseAlert(), AlertManager__TempSeverity().
 * MockUartDriver is a traditional mock that coexists with Partials - the
 * private AlertManager__RaiseAlert() calls UartDriver_SendByte(), which is
 * intercepted by the traditional mock in the same test file. */

#include "unity.h"
#include "ceedling.h"
#include "MockUartDriver.h"

#include TEST_PARTIAL_ALL_MODULE(AlertManager)

#include "Types.h"

void setUp(void)
{
    AlertManager_Init();
}

void tearDown(void)
{
}

void test_TempSeverity_AboveHighThresholdReturnsHigh(void)
{
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_HIGH, AlertManager__TempSeverity(40001));
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_HIGH, AlertManager__TempSeverity(50000));
}

void test_TempSeverity_BelowLowThresholdReturnsMedium(void)
{
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_MEDIUM, AlertManager__TempSeverity(-10001));
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_MEDIUM, AlertManager__TempSeverity(-20000));
}

void test_TempSeverity_WithinRangeReturnsNone(void)
{
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_NONE, AlertManager__TempSeverity(25000));
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_NONE, AlertManager__TempSeverity(40000));
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_NONE, AlertManager__TempSeverity(-10000));
}

void test_FindFreeSlot_ReturnsZeroOnEmptyTable(void)
{
    TEST_ASSERT_EQUAL_INT8(0, AlertManager__FindFreeSlot());
}

void test_FindFreeSlot_ReturnsNegativeOneWhenTableFull(void)
{
    uint8 i;
    for (i = 0u; i < ALERT_MANAGER_MAX_ALERTS; i++)
    {
        UartDriver_SendByte_Expect('^');
        AlertManager__RaiseAlert(ALERT_SEVERITY_HIGH, EVENT_TEMP_HIGH);
    }
    TEST_ASSERT_EQUAL_INT8(-1, AlertManager__FindFreeSlot());
}

void test_RaiseAlert_CriticalSendsExclamation(void)
{
    UartDriver_SendByte_Expect('!');
    AlertManager__RaiseAlert(ALERT_SEVERITY_CRITICAL, EVENT_TEMP_HIGH);
    TEST_ASSERT_EQUAL_UINT8(1u, AlertManager_GetActiveAlertCount());
}

void test_RaiseAlert_MediumSendsTilde(void)
{
    UartDriver_SendByte_Expect('~');
    AlertManager__RaiseAlert(ALERT_SEVERITY_MEDIUM, EVENT_TEMP_LOW);
    TEST_ASSERT_EQUAL_UINT8(1u, AlertManager_GetActiveAlertCount());
}

void test_EvaluateTemperature_NoAlertWithinNormalRange(void)
{
    AlertManager_EvaluateTemperature(25000);
    TEST_ASSERT_EQUAL_UINT8(0u, AlertManager_GetActiveAlertCount());
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_NONE, AlertManager_GetHighestSeverity());
}

void test_EvaluateTemperature_AlertWhenTooHot(void)
{
    UartDriver_SendByte_Expect('^');
    AlertManager_EvaluateTemperature(45000);
    TEST_ASSERT_EQUAL_UINT8(1u, AlertManager_GetActiveAlertCount());
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_HIGH, AlertManager_GetHighestSeverity());
}

void test_ClearAll_ResetsAlertCount(void)
{
    UartDriver_SendByte_Expect('^');
    AlertManager_EvaluateTemperature(45000);
    TEST_ASSERT_EQUAL_UINT8(1u, AlertManager_GetActiveAlertCount());

    AlertManager_ClearAll();
    TEST_ASSERT_EQUAL_UINT8(0u, AlertManager_GetActiveAlertCount());
    TEST_ASSERT_EQUAL_INT(ALERT_SEVERITY_NONE, AlertManager_GetHighestSeverity());
}
