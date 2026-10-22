/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Exercises #include-discovery scenarios that already work correctly without
 * any source fix -- a regression guard locked in before touching the
 * includes-discovery pipeline:
 *   (a) conditional include gated on a project :defines macro
 *   (b) conditional include gated on a same-file #define
 *   (c) a header reached only transitively (never itself directly
 *       #include'd by widget.c) correctly not duplicated in as a false
 *       top-level entry
 *   (e) an #include whose own target is a macro, not a literal filename --
 *       only resolvable by real preprocessing (gcc's bare pass), never by
 *       the literal text scan issue #1223's fix added */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(widget)

void setUp(void)
{
}

void tearDown(void)
{
}

void test_FromProjectFlag_ReturnsProjectFlagMacro(void)
{
    TEST_ASSERT_EQUAL_INT(13, Widget__FromProjectFlag());
}

void test_FromLocalFlag_ReturnsLocalFlagMacro(void)
{
    TEST_ASSERT_EQUAL_INT(11, Widget__FromLocalFlag());
}

void test_FromNested_ReturnsNestedMacro(void)
{
    TEST_ASSERT_EQUAL_INT(17, Widget__FromNested());
}

void test_FromMacroInclude_ReturnsMacroTargetValue(void)
{
    TEST_ASSERT_EQUAL_INT(19, Widget__FromMacroInclude());
}
