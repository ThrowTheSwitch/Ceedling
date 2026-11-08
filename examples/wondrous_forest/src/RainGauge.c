/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "RainGauge.h"
#include "ForestUnits.h"
#include "UartDriver.h"

/* Makes this file hold the external definition of a ForestUnits.h inline function */
extern inline uint32 ForestUnits_MicrometersToTenthsMm(uint32 micrometers);

static uint32 s_tips_at_update;
static uint32 s_rainfall_um;
static bool   s_storm;

void RainGauge_Init(void)
{
    s_tips_at_update = g_rain_tip_count;
    s_rainfall_um    = 0u;
    s_storm          = false;
}

/* Adds the rain since the last update and reports a storm once, as it begins */
void RainGauge_Update(void)
{
    uint32 tips      = g_rain_tip_count;
    uint32 minute_um = RainGauge_TipsToMicrometers(tips - s_tips_at_update);
    bool   storm     = (minute_um * RAIN_GAUGE_UPDATES_PER_HOUR) >= RAIN_GAUGE_STORM_UM_PER_HOUR;

    s_tips_at_update = tips;
    s_rainfall_um   += minute_um;

    if (storm && !s_storm) { RainGauge_ReportStorm(); }
    s_storm = storm;
}

uint32 RainGauge_GetRainfallUm(void)
{
    return s_rainfall_um;
}

uint32 RainGauge_GetRainfallTenthsMm(void)
{
    return ForestUnits_MicrometersToTenthsMm(s_rainfall_um);
}

bool RainGauge_IsStorm(void)
{
    return s_storm;
}

void RainGauge_ReportStorm(void)
{
    UartDriver_SendString("STORM\r\n");
}
