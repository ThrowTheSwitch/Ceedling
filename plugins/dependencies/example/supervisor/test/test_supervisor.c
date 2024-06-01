/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifdef TEST

#include "unity.h"

#include "supervisor.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_supervisor_can_DelegateProperlyToLeastBusyWorker(void)
{
    int loads1[] = { 1, 2, 3, 4 };
    int loads2[] = { 2, 1, 3, 4 };
    int loads3[] = { 2, 1, 0, 8 };
    int loads4[] = { 9, 9, 7, 0 };
    int loads5[] = { 0, 0, 1, 4 };

    TEST_ASSERT_EQUAL(0, supervisor_delegate(loads1, 2));
    TEST_ASSERT_EQUAL(0, supervisor_delegate(loads1, 4));
    TEST_ASSERT_EQUAL(1, supervisor_delegate(loads2, 4));
    TEST_ASSERT_EQUAL(2, supervisor_delegate(loads3, 4));
    TEST_ASSERT_EQUAL(2, supervisor_delegate(loads3, 3));
    TEST_ASSERT_EQUAL(3, supervisor_delegate(loads4, 4));
    TEST_ASSERT_EQUAL(0, supervisor_delegate(loads5, 4));
    TEST_ASSERT_EQUAL(0, supervisor_delegate(loads5, 2));
}

void test_supervisor_can_TrackProgressProperlyAcrossAllWorkers(void)
{
    int loads1[] = { 1, 2, 3, 4 };
    int loads2[] = { 2, 1, 3, 4 };
    int loads3[] = { 2, 1, 0, 8 };
    int loads4[] = { 9, 9, 7, 0 };
    int loads5[] = { 0, 0, 1, 4 };

    TEST_ASSERT_EQUAL(3,  supervisor_progress(loads1, 2));
    TEST_ASSERT_EQUAL(10, supervisor_progress(loads1, 4));
    TEST_ASSERT_EQUAL(10, supervisor_progress(loads2, 4));
    TEST_ASSERT_EQUAL(11, supervisor_progress(loads3, 4));
    TEST_ASSERT_EQUAL(3,  supervisor_progress(loads3, 3));
    TEST_ASSERT_EQUAL(25, supervisor_progress(loads4, 4));
    TEST_ASSERT_EQUAL(5,  supervisor_progress(loads5, 4));
    TEST_ASSERT_EQUAL(0,  supervisor_progress(loads5, 2));
}

#endif 
