/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "unity_internals.h"
#include "UnityHelper.h"

#if TEST_CUSTOM_EXAMPLE_STRUCT_T
void AssertEqualEXAMPLE_STRUCT_T(const EXAMPLE_STRUCT_T expected, const EXAMPLE_STRUCT_T actual, const unsigned short line)
{
  UNITY_TEST_ASSERT_EQUAL_INT(expected.x, actual.x, line, "EXAMPLE_STRUCT_T.x check failed");
  UNITY_TEST_ASSERT_EQUAL_INT(expected.y, actual.y, line, "EXAMPLE_STRUCT_T.y check failed");
}
#endif

