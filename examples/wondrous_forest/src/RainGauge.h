/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef RAIN_GAUGE_H
#define RAIN_GAUGE_H

#include "Types.h"

/* A tipping-bucket gauge. The bucket tips once for each 0.2 mm of rain. */
#define RAIN_GAUGE_UM_PER_TIP           (200u)

/* Rain falling at 20 mm per hour or more is a storm */
#define RAIN_GAUGE_STORM_UM_PER_HOUR    (20000u)

/* The station updates the gauge once a minute */
#define RAIN_GAUGE_UPDATES_PER_HOUR     (60u)

/* Bucket tips since power-up. The tip interrupt in RainTipIsr.c defines and
 * counts it. */
extern uint32 g_rain_tip_count;

/* Shared with the station's display code, which shows rainfall between updates */
static inline uint32 RainGauge_TipsToMicrometers(uint32 tips)
{
    return tips * RAIN_GAUGE_UM_PER_TIP;
}

void   RainGauge_Init(void);
void   RainGauge_Update(void);
uint32 RainGauge_GetRainfallUm(void);
uint32 RainGauge_GetRainfallTenthsMm(void);
bool   RainGauge_IsStorm(void);
void   RainGauge_ReportStorm(void);

#endif /* RAIN_GAUGE_H */
