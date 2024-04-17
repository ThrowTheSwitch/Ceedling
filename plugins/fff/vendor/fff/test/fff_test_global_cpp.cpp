/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */



extern "C"{
    #include "global_fakes.h"
}
#include <gtest/gtest.h>

DEFINE_FFF_GLOBALS;

class FFFTestSuite: public testing::Test
{
public:
    void SetUp()
    {
        RESET_FAKE(voidfunc1);
        RESET_FAKE(voidfunc2);
        RESET_FAKE(longfunc0);
        FFF_RESET_HISTORY();
    }
};

#include "test_cases.include"


