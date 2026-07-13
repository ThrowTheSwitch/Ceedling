/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef EVENT_QUEUE_H
#define EVENT_QUEUE_H

#include "Types.h"

#define EVENT_QUEUE_CAPACITY (16u)

void  EventQueue_Init(void);
bool  EventQueue_Push(const ForestEvent_t* event);
bool  EventQueue_Pop(ForestEvent_t* event_out);
bool  EventQueue_IsEmpty(void);
bool  EventQueue_IsFull(void);
uint8 EventQueue_Count(void);

#endif /* EVENT_QUEUE_H */
