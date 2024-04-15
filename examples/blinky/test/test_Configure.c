/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Configure.h"
#include "stub_io.h"
#include "mock_stub_interrupt.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_Configure_should_setup_timer_and_port(void)
    {
    /* Ensure known test state */

    /* Setup expected call chain */
    //these are defined into assembly instructions. 
    cli_Expect(); 
    sei_Expect();
    /* Call function under test */
    Configure();

    /* Verify test results */
    TEST_ASSERT_EQUAL_INT(3, TCCR0B);
    TEST_ASSERT_EQUAL_INT(1, TIMSK0);
    TEST_ASSERT_EQUAL_INT(0x20, DDRB);
}
