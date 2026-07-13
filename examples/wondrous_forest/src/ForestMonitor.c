/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "ForestMonitor.h"
#include "TemperatureSensor.h"
#include "HumiditySensor.h"
#include "SoilMoisture.h"
#include "AlertManager.h"
#include "EventQueue.h"
#include "UartDriver.h"

static MonitorState_t s_current_state;
static uint32         s_tick_counter;

static MonitorState_t ForestMonitor__NextState(MonitorState_t current)
{
    switch (current)
    {
        case MONITOR_STATE_IDLE:       return MONITOR_STATE_SAMPLING;
        case MONITOR_STATE_SAMPLING:   return MONITOR_STATE_EVALUATING;
        case MONITOR_STATE_EVALUATING: return (AlertManager_GetActiveAlertCount() > 0u)
                                              ? MONITOR_STATE_ALERTING
                                              : MONITOR_STATE_REPORTING;
        case MONITOR_STATE_ALERTING:   return MONITOR_STATE_REPORTING;
        case MONITOR_STATE_REPORTING:  return MONITOR_STATE_IDLE;
        default:                       return MONITOR_STATE_IDLE;
    }
}

void ForestMonitor_Init(void)
{
    s_current_state = MONITOR_STATE_IDLE;
    s_tick_counter  = 0u;
    AlertManager_Init();
    EventQueue_Init();
}

void ForestMonitor_Tick(void)
{
    s_tick_counter++;

    switch (s_current_state)
    {
        case MONITOR_STATE_IDLE:
            break;

        case MONITOR_STATE_SAMPLING:
            TemperatureSensor_Sample();
            HumiditySensor_Sample();
            SoilMoisture_Sample();
            break;

        case MONITOR_STATE_EVALUATING:
            AlertManager_EvaluateTemperature(TemperatureSensor_GetMilliCelsius());
            AlertManager_EvaluateHumidity(HumiditySensor_GetPercent());
            AlertManager_EvaluateSoilMoisture(SoilMoisture_GetPercent());
            break;

        case MONITOR_STATE_ALERTING:
            UartDriver_SendString("ALERT\r\n");
            break;

        case MONITOR_STATE_REPORTING:
            UartDriver_SendString("OK\r\n");
            AlertManager_ClearAll();
            break;

        default:
            break;
    }

    s_current_state = ForestMonitor__NextState(s_current_state);
}

MonitorState_t ForestMonitor_GetState(void)
{
    return s_current_state;
}

bool ForestMonitor_HasPendingAlerts(void)
{
    return AlertManager_GetActiveAlertCount() > 0u;
}
