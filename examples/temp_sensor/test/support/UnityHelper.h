/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _TESTHELPER_H
#define _TESTHELPER_H

#if TEST_CUSTOM_EXAMPLE_STRUCT_T
#include "Types.h"
void AssertEqualEXAMPLE_STRUCT_T(const EXAMPLE_STRUCT_T expected, const EXAMPLE_STRUCT_T actual, const unsigned short line);
#define UNITY_TEST_ASSERT_EQUAL_EXAMPLE_STRUCT_T(expected, actual, line, message) {AssertEqualEXAMPLE_STRUCT_T(expected, actual, line);}
#endif

#endif // _TESTHELPER_H
