/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_PUBLIC_MODULE + MOCK_PARTIAL_PRIVATE_MODULE
 * Tests the public state machine interface while mocking the private
 * ForestMonitor__NextState() transition function.
 * The file-scoped static s_current_state is exposed as extern by Partials,
 * allowing direct state injection to test each state branch in isolation.
 * Six traditional mocks coexist alongside the Partial mock. */

#include "unity.h"
#include "ceedling.h"
#include "MockTemperatureSensor.h"
#include "MockHumiditySensor.h"
#include "MockSoilMoisture.h"
#include "MockAlertManager.h"
#include "MockEventQueue.h"
#include "MockUartDriver.h"

#include TEST_PARTIAL_PUBLIC_MODULE(ForestMonitor)
#include MOCK_PARTIAL_PRIVATE_MODULE(ForestMonitor)

#include "Types.h"

void setUp(void)
{
    AlertManager_Init_Expect();
    EventQueue_Init_Expect();
    ForestMonitor_Init();
}

void tearDown(void)
{
}

void test_Init_SetsStateToIdle(void)
{
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_IDLE, ForestMonitor_GetState());
}

void test_Tick_InIdleStateTransitionsViaNextState(void)
{
    ForestMonitor__NextState_ExpectAndReturn(MONITOR_STATE_IDLE, MONITOR_STATE_SAMPLING);
    ForestMonitor_Tick();
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_SAMPLING, ForestMonitor_GetState());
}

void test_Tick_InSamplingStateSamplesAllSensors(void)
{
    /* s_current_state is a file-scoped static exposed as extern by TEST_PARTIAL_PUBLIC_MODULE */
    s_current_state = MONITOR_STATE_SAMPLING;

    TemperatureSensor_Sample_ExpectAndReturn(true);
    HumiditySensor_Sample_ExpectAndReturn(true);
    SoilMoisture_Sample_ExpectAndReturn(true);
    ForestMonitor__NextState_ExpectAndReturn(MONITOR_STATE_SAMPLING, MONITOR_STATE_EVALUATING);

    ForestMonitor_Tick();
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_EVALUATING, ForestMonitor_GetState());
}

void test_Tick_InEvaluatingStateCallsAlertEvaluations(void)
{
    s_current_state = MONITOR_STATE_EVALUATING;

    /* Strict ordering: C evaluates each argument before its enclosing call,
     * so GetMilliCelsius is called before EvaluateTemperature, etc. */
    TemperatureSensor_GetMilliCelsius_ExpectAndReturn(25000);
    AlertManager_EvaluateTemperature_Expect(25000);
    HumiditySensor_GetPercent_ExpectAndReturn(60u);
    AlertManager_EvaluateHumidity_Expect(60u);
    SoilMoisture_GetPercent_ExpectAndReturn(55u);
    AlertManager_EvaluateSoilMoisture_Expect(55u);
    ForestMonitor__NextState_ExpectAndReturn(MONITOR_STATE_EVALUATING, MONITOR_STATE_REPORTING);

    ForestMonitor_Tick();
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_REPORTING, ForestMonitor_GetState());
}

void test_Tick_InAlertingStateSendsAlertString(void)
{
    s_current_state = MONITOR_STATE_ALERTING;

    UartDriver_SendString_Expect("ALERT\r\n");
    ForestMonitor__NextState_ExpectAndReturn(MONITOR_STATE_ALERTING, MONITOR_STATE_REPORTING);

    ForestMonitor_Tick();
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_REPORTING, ForestMonitor_GetState());
}

void test_Tick_InReportingStateSendsOkAndClearsAlerts(void)
{
    s_current_state = MONITOR_STATE_REPORTING;

    UartDriver_SendString_Expect("OK\r\n");
    AlertManager_ClearAll_Expect();
    ForestMonitor__NextState_ExpectAndReturn(MONITOR_STATE_REPORTING, MONITOR_STATE_IDLE);

    ForestMonitor_Tick();
    TEST_ASSERT_EQUAL_INT(MONITOR_STATE_IDLE, ForestMonitor_GetState());
}

void test_HasPendingAlerts_ReflectsAlertManagerCount(void)
{
    AlertManager_GetActiveAlertCount_ExpectAndReturn(3u);
    TEST_ASSERT_TRUE(ForestMonitor_HasPendingAlerts());

    AlertManager_GetActiveAlertCount_ExpectAndReturn(0u);
    TEST_ASSERT_FALSE(ForestMonitor_HasPendingAlerts());
}
