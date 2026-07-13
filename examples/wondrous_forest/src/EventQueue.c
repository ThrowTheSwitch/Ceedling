/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "EventQueue.h"

static ForestEvent_t s_queue_storage[EVENT_QUEUE_CAPACITY];
static uint8         s_head;
static uint8         s_tail;
static uint8         s_count;

static inline uint8 EventQueue__AdvanceIndex(uint8 index)
{
    return (uint8)((index + 1u) % EVENT_QUEUE_CAPACITY);
}

static inline bool EventQueue__IsEmpty(uint8 count)
{
    return count == 0u;
}

static inline bool EventQueue__IsFull(uint8 count)
{
    return count >= EVENT_QUEUE_CAPACITY;
}

void EventQueue_Init(void)
{
    s_head  = 0u;
    s_tail  = 0u;
    s_count = 0u;
}

bool EventQueue_Push(const ForestEvent_t* event)
{
    if (event == NULL)               { return false; }
    if (EventQueue__IsFull(s_count)) { return false; }

    s_queue_storage[s_tail] = *event;
    s_tail                  = EventQueue__AdvanceIndex(s_tail);
    s_count++;
    return true;
}

bool EventQueue_Pop(ForestEvent_t* event_out)
{
    if (event_out == NULL)            { return false; }
    if (EventQueue__IsEmpty(s_count)) { return false; }

    *event_out = s_queue_storage[s_head];
    s_head     = EventQueue__AdvanceIndex(s_head);
    s_count--;
    return true;
}

bool EventQueue_IsEmpty(void)
{
    return EventQueue__IsEmpty(s_count);
}

bool EventQueue_IsFull(void)
{
    return EventQueue__IsFull(s_count);
}

uint8 EventQueue_Count(void)
{
    return s_count;
}
