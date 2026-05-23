/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef FOREST_MONITOR_H
#define FOREST_MONITOR_H

#include "Types.h"

void           ForestMonitor_Init(void);
void           ForestMonitor_Tick(void);
MonitorState_t ForestMonitor_GetState(void);
bool           ForestMonitor_HasPendingAlerts(void);

#endif /* FOREST_MONITOR_H */
