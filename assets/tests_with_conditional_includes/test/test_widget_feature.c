/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Regression test for #1223: without the fix, this fails to *compile* --
 * FEATURE_EXTRA_MACRO is undeclared in the generated Partial implementation
 * because feature_extra.h's conditional #include (guarded by a macro from
 * an earlier #include in widget_feature.c) is silently dropped. See
 * widget_feature.c for the full explanation. */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(widget_feature)

void setUp(void)
{
}

void tearDown(void)
{
}

void test_FromFeatureLevel_ReturnsFeatureExtraMacro(void)
{
    TEST_ASSERT_EQUAL_INT(7, WidgetFeature__FromFeatureLevel());
}
