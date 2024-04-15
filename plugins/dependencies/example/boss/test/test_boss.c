/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifdef TEST

#include "unity.h"

#include "mock_supervisor.h"
#include "mock_libworker.h"
#include "boss.h"


extern int hours_worked[];
extern int total_workers;
extern int total_hours;

void setUp(void)
{
    boss_start();
}

void tearDown(void)
{
}

void test_boss_start_ResetsAllTheStuff(void)
{
    int i;

    total_workers = 3;
    total_hours = 33;

    for (i=0; i < 3; i++)
    {
        hours_worked[i] = i+1;
    }

    boss_start();

    TEST_ASSERT_EQUAL_INT(0, total_workers);
    TEST_ASSERT_EQUAL_INT(0, total_hours);
    TEST_ASSERT_EQUAL_INT(0, hours_worked[0]);
    TEST_ASSERT_EQUAL_INT(0, hours_worked[1]);
    TEST_ASSERT_EQUAL_INT(0, hours_worked[2]);
}

void test_boss_can_HireAndFireWorkers(void)
{
    TEST_ASSERT_EQUAL(0, total_workers);

    boss_hire_workers(3);
    TEST_ASSERT_EQUAL(3, total_workers);

    boss_hire_workers(1);
    boss_hire_workers(7);
    TEST_ASSERT_EQUAL(11, total_workers);

    boss_hire_workers(0);
    TEST_ASSERT_EQUAL(11, total_workers);

    boss_hire_workers(-1);
    TEST_ASSERT_EQUAL(11, total_workers);

    boss_fire_workers(3);
    TEST_ASSERT_EQUAL(8, total_workers);

    boss_fire_workers(2);
    boss_fire_workers(4);
    TEST_ASSERT_EQUAL(2, total_workers);

    boss_fire_workers(0);
    TEST_ASSERT_EQUAL(2, total_workers);

    boss_fire_workers(-1);
    TEST_ASSERT_EQUAL(2, total_workers);

    boss_hire_workers(18);
    TEST_ASSERT_EQUAL(20, total_workers);

    boss_fire_workers(20);
    TEST_ASSERT_EQUAL(0, total_workers);

    boss_fire_workers(5);
    TEST_ASSERT_EQUAL(0, total_workers);
}

void test_boss_can_MicroManageLikeABoss(void)
{
    /* An ever-increasing amount of work. this boss is kinda mean. */
    int i;
    const int work_to_do[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };

    worker_start_over_Ignore();
    worker_work_Ignore();
    worker_progress_IgnoreAndReturn(1);
    supervisor_progress_IgnoreAndReturn(36);

    for (i=0; i < 8; i++)
    {
        supervisor_delegate_IgnoreAndReturn(i % 4);
    }

    /* assign all the hours */
    boss_hire_workers(4);
    TEST_ASSERT_EQUAL_INT(36, boss_micro_manage(work_to_do, 8));

    /* make sure everyone has work to do */
    for (i=0; i < 4; i++)
    {
        TEST_ASSERT_NOT_EQUAL_INT(0, hours_worked[i]);
    }
}

#endif 
