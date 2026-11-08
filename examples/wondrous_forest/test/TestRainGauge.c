/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_PUBLIC_MODULE + TEST_PARTIAL_CONFIG subtraction
 * Tests RainGauge's public functions. The Partial carries what they rely on
 * beyond the functions this test selects:
 *  - RainGauge_TipsToMicrometers(), a static inline helper RainGauge.h defines.
 *  - The extern inline prototype that makes RainGauge.c hold the external
 *    definition of ForestUnits_MicrometersToTenthsMm().
 *  - The prototype of RainGauge_ReportStorm(), which this test subtracts and
 *    stubs below.
 * RainGauge.h declares g_rain_tip_count extern. RainTipIsr.c defines it, and
 * this test links RainTipIsr.c to simulate bucket tips. The Partial's weak
 * definition of the counter gives way to that real one.
 * Run with --verbosity=debug to see what the Partial carries and why. */

#include "unity.h"
#include "ceedling.h"
#include "RainTipIsr.h"

#include TEST_PARTIAL_PUBLIC_MODULE(RainGauge)
TEST_PARTIAL_CONFIG(RainGauge, -RainGauge_ReportStorm)

#include "Types.h"

static uint8 s_storm_reports;

/* Stands in for the subtracted RainGauge_ReportStorm(). The carried prototype
 * lets RainGauge_Update() call it. */
void RainGauge_ReportStorm(void)
{
    s_storm_reports++;
}

static void TipBucket(uint32 times)
{
    while (times-- > 0u) { RainTipIsr_Handler(); }
}

void setUp(void)
{
    g_rain_tip_count = 0u;
    s_storm_reports  = 0u;
    RainGauge_Init();
}

void tearDown(void)
{
}

void test_Rainfall_StartsAtZero(void)
{
    TEST_ASSERT_EQUAL_UINT32(0u, RainGauge_GetRainfallUm());
}

void test_Init_IgnoresTipsBeforeIt(void)
{
    TipBucket(4u);
    RainGauge_Init();
    RainGauge_Update();
    TEST_ASSERT_EQUAL_UINT32(0u, RainGauge_GetRainfallUm());
}

void test_Update_AddsTwoTenthsOfAMillimeterPerTip(void)
{
    TipBucket(3u);
    RainGauge_Update();
    TEST_ASSERT_EQUAL_UINT32(600u, RainGauge_GetRainfallUm());
}

void test_Update_AccumulatesRainfallAcrossUpdates(void)
{
    TipBucket(1u);
    RainGauge_Update();
    TipBucket(1u);
    RainGauge_Update();
    TEST_ASSERT_EQUAL_UINT32(400u, RainGauge_GetRainfallUm());
}

void test_GetRainfallTenthsMm_ConvertsMicrometers(void)
{
    /* 5 tips = 1000 um = 1.0 mm */
    TipBucket(5u);
    RainGauge_Update();
    TEST_ASSERT_EQUAL_UINT32(10u, RainGauge_GetRainfallTenthsMm());
}

void test_Update_OneTipAMinuteIsNotAStorm(void)
{
    /* 200 um in a minute = 12 mm per hour */
    TipBucket(1u);
    RainGauge_Update();
    TEST_ASSERT_FALSE(RainGauge_IsStorm());
    TEST_ASSERT_EQUAL_UINT8(0u, s_storm_reports);
}

void test_Update_TwoTipsAMinuteReportAStorm(void)
{
    /* 400 um in a minute = 24 mm per hour */
    TipBucket(2u);
    RainGauge_Update();
    TEST_ASSERT_TRUE(RainGauge_IsStorm());
    TEST_ASSERT_EQUAL_UINT8(1u, s_storm_reports);
}

void test_Update_ReportsAContinuingStormOnce(void)
{
    TipBucket(2u);
    RainGauge_Update();
    TipBucket(3u);
    RainGauge_Update();
    TEST_ASSERT_TRUE(RainGauge_IsStorm());
    TEST_ASSERT_EQUAL_UINT8(1u, s_storm_reports);
}

void test_Update_EndsTheStormWhenRainEases(void)
{
    TipBucket(2u);
    RainGauge_Update();
    RainGauge_Update();
    TEST_ASSERT_FALSE(RainGauge_IsStorm());
}
