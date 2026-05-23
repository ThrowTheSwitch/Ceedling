/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "AlertManager.h"
#include "UartDriver.h"

#define TEMP_HIGH_THRESHOLD_MC  (40000)
#define TEMP_LOW_THRESHOLD_MC   (-10000)
#define HUMIDITY_HIGH_THRESHOLD (90u)
#define HUMIDITY_LOW_THRESHOLD  (10u)
#define SOIL_DRY_THRESHOLD      (20u)

static AlertEntry_t s_alert_table[ALERT_MANAGER_MAX_ALERTS];
static uint8        s_alert_count;

static int8 AlertManager__FindFreeSlot(void)
{
    uint8 i;
    for (i = 0u; i < ALERT_MANAGER_MAX_ALERTS; i++)
    {
        if (!s_alert_table[i].active) { return (int8)i; }
    }
    return -1;
}

static void AlertManager__RaiseAlert(AlertSeverity_t severity, EventType_t event_type)
{
    int8 slot = AlertManager__FindFreeSlot();
    if (slot < 0) { return; }

    s_alert_table[(uint8)slot].severity   = severity;
    s_alert_table[(uint8)slot].event_type = event_type;
    s_alert_table[(uint8)slot].active     = true;
    s_alert_count++;

    switch (severity)
    {
        case ALERT_SEVERITY_CRITICAL: UartDriver_SendByte('!'); break;
        case ALERT_SEVERITY_HIGH:     UartDriver_SendByte('^'); break;
        case ALERT_SEVERITY_MEDIUM:   UartDriver_SendByte('~'); break;
        default:                      UartDriver_SendByte('.'); break;
    }
}

static AlertSeverity_t AlertManager__TempSeverity(int32 milli_celsius)
{
    if (milli_celsius > TEMP_HIGH_THRESHOLD_MC) { return ALERT_SEVERITY_HIGH; }
    if (milli_celsius < TEMP_LOW_THRESHOLD_MC)  { return ALERT_SEVERITY_MEDIUM; }
    return ALERT_SEVERITY_NONE;
}

void AlertManager_Init(void)
{
    uint8 i;
    for (i = 0u; i < ALERT_MANAGER_MAX_ALERTS; i++)
    {
        s_alert_table[i].active     = false;
        s_alert_table[i].severity   = ALERT_SEVERITY_NONE;
        s_alert_table[i].event_type = EVENT_NONE;
    }
    s_alert_count = 0u;
}

void AlertManager_EvaluateTemperature(int32 milli_celsius)
{
    AlertSeverity_t sev = AlertManager__TempSeverity(milli_celsius);
    if (sev == ALERT_SEVERITY_NONE) { return; }

    EventType_t evt = (milli_celsius > TEMP_HIGH_THRESHOLD_MC) ? EVENT_TEMP_HIGH : EVENT_TEMP_LOW;
    AlertManager__RaiseAlert(sev, evt);
}

void AlertManager_EvaluateHumidity(uint8 percent)
{
    if (percent > HUMIDITY_HIGH_THRESHOLD)
    {
        AlertManager__RaiseAlert(ALERT_SEVERITY_LOW, EVENT_HUMIDITY_HIGH);
    }
    else if (percent < HUMIDITY_LOW_THRESHOLD)
    {
        AlertManager__RaiseAlert(ALERT_SEVERITY_MEDIUM, EVENT_HUMIDITY_LOW);
    }
}

void AlertManager_EvaluateSoilMoisture(uint8 percent)
{
    if (percent < SOIL_DRY_THRESHOLD)
    {
        AlertManager__RaiseAlert(ALERT_SEVERITY_HIGH, EVENT_SOIL_DRY);
    }
}

AlertSeverity_t AlertManager_GetHighestSeverity(void)
{
    AlertSeverity_t highest = ALERT_SEVERITY_NONE;
    uint8 i;
    for (i = 0u; i < ALERT_MANAGER_MAX_ALERTS; i++)
    {
        if (s_alert_table[i].active && s_alert_table[i].severity > highest)
        {
            highest = s_alert_table[i].severity;
        }
    }
    return highest;
}

uint8 AlertManager_GetActiveAlertCount(void)
{
    return s_alert_count;
}

void AlertManager_ClearAll(void)
{
    uint8 i;
    for (i = 0u; i < ALERT_MANAGER_MAX_ALERTS; i++)
    {
        s_alert_table[i].active = false;
    }
    s_alert_count = 0u;
}
