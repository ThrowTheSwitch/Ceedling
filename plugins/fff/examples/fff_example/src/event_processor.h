/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include <stdbool.h>

void event_deviceReset(void);
void event_volumeKnobMaxed(void);
void event_powerReadingUpdate(int powerReading);
void event_modeSelectButtonPressed(void);
void event_devicePoweredOn(void);
void event_keyboardCheckTimerExpired(void);
void event_newDataAvailable(int data);

bool eventProcessor_isLastEventComplete(void);
