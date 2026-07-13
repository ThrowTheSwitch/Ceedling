/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef ALERT_MANAGER_H
#define ALERT_MANAGER_H

#include "Types.h"

#define ALERT_MANAGER_MAX_ALERTS (8u)

typedef struct
{
    AlertSeverity_t severity;
    EventType_t     event_type;
    bool            active;
} AlertEntry_t;

void            AlertManager_Init(void);
void            AlertManager_EvaluateTemperature(int32 milli_celsius);
void            AlertManager_EvaluateHumidity(uint8 percent);
void            AlertManager_EvaluateSoilMoisture(uint8 percent);
AlertSeverity_t AlertManager_GetHighestSeverity(void);
uint8           AlertManager_GetActiveAlertCount(void);
void            AlertManager_ClearAll(void);

#endif /* ALERT_MANAGER_H */
