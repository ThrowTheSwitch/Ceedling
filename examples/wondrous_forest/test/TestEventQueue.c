/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Partials pattern: TEST_PARTIAL_ALL_MODULE
 * Tests private static inline helpers EventQueue__AdvanceIndex(),
 * EventQueue__IsEmpty(), and EventQueue__IsFull() directly.
 * Also accesses file-scoped statics s_head, s_tail, s_count as extern
 * to verify internal state after push/pop operations.
 * Uses ALL variant so both public API and private internals are available. */

#include "unity.h"
#include "ceedling.h"

#include TEST_PARTIAL_ALL_MODULE(EventQueue)

#include "Types.h"

void setUp(void)
{
    EventQueue_Init();
}

void tearDown(void)
{
}

void test_AdvanceIndex_NormalIncrement(void)
{
    TEST_ASSERT_EQUAL_UINT8(1u, EventQueue__AdvanceIndex(0u));
    TEST_ASSERT_EQUAL_UINT8(7u, EventQueue__AdvanceIndex(6u));
}

void test_AdvanceIndex_WrapsAroundAtCapacity(void)
{
    TEST_ASSERT_EQUAL_UINT8(0u, EventQueue__AdvanceIndex((uint8)(EVENT_QUEUE_CAPACITY - 1u)));
}

void test_IsEmptyHelper_TrueWhenCountIsZero(void)
{
    TEST_ASSERT_TRUE(EventQueue__IsEmpty(0u));
}

void test_IsEmptyHelper_FalseWhenCountNonZero(void)
{
    TEST_ASSERT_FALSE(EventQueue__IsEmpty(1u));
    TEST_ASSERT_FALSE(EventQueue__IsEmpty(EVENT_QUEUE_CAPACITY));
}

void test_IsFullHelper_TrueAtCapacity(void)
{
    TEST_ASSERT_TRUE(EventQueue__IsFull(EVENT_QUEUE_CAPACITY));
    TEST_ASSERT_TRUE(EventQueue__IsFull(EVENT_QUEUE_CAPACITY + 1u));
}

void test_IsFullHelper_FalseWhenSpaceRemains(void)
{
    TEST_ASSERT_FALSE(EventQueue__IsFull(0u));
    TEST_ASSERT_FALSE(EventQueue__IsFull(EVENT_QUEUE_CAPACITY - 1u));
}

void test_Init_SetsHeadTailCountToZero(void)
{
    /* s_head, s_tail, s_count are file-scoped statics exposed as extern by Partials */
    EventQueue_Init();
    TEST_ASSERT_EQUAL_UINT8(0u, s_head);
    TEST_ASSERT_EQUAL_UINT8(0u, s_tail);
    TEST_ASSERT_EQUAL_UINT8(0u, s_count);
}

void test_Push_AdvancesTailAndIncreasesCount(void)
{
    ForestEvent_t evt = { EVENT_TEMP_HIGH, 12345u, 42000 };
    EventQueue_Push(&evt);

    TEST_ASSERT_EQUAL_UINT8(0u, s_head);
    TEST_ASSERT_EQUAL_UINT8(1u, s_tail);
    TEST_ASSERT_EQUAL_UINT8(1u, s_count);
}

void test_Pop_AdvancesHeadAndDecreasesCount(void)
{
    ForestEvent_t evt_in  = { EVENT_HUMIDITY_HIGH, 99u, 75 };
    ForestEvent_t evt_out = { EVENT_NONE, 0u, 0 };

    EventQueue_Push(&evt_in);
    EventQueue_Pop(&evt_out);

    TEST_ASSERT_EQUAL_UINT8(0u, s_count);
    TEST_ASSERT_EQUAL_INT(EVENT_HUMIDITY_HIGH, evt_out.type);
    TEST_ASSERT_EQUAL_UINT32(99u, evt_out.timestamp_ms);
}

void test_Queue_FillAndDrainCycle(void)
{
    ForestEvent_t evt = { EVENT_SOIL_DRY, 1u, 10 };
    uint8 i;

    for (i = 0u; i < EVENT_QUEUE_CAPACITY; i++)
    {
        evt.value = (int32)i;
        TEST_ASSERT_TRUE(EventQueue_Push(&evt));
    }
    TEST_ASSERT_TRUE(EventQueue_IsFull());
    TEST_ASSERT_FALSE(EventQueue_Push(&evt)); /* overfill rejected */

    for (i = 0u; i < EVENT_QUEUE_CAPACITY; i++)
    {
        ForestEvent_t out;
        TEST_ASSERT_TRUE(EventQueue_Pop(&out));
        TEST_ASSERT_EQUAL_INT32((int32)i, out.value);
    }
    TEST_ASSERT_TRUE(EventQueue_IsEmpty());
}
