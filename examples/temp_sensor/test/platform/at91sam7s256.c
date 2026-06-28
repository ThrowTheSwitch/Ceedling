/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/*
 * Platform standin instance definitions.
 *
 * One global struct per peripheral. All fields are zero-initialized by
 * default (C static storage). Test setUp() functions memset these to zero
 * before each test to guarantee a clean starting state regardless of what
 * a previous test may have written.
 */

#include "at91sam7s256.h"

AT91S_ADC  AdcStandin;
AT91S_TC   TimerStandin;
AT91S_US   UsartStandin;
AT91S_PIO  PioAStandin;
AT91S_PIO  PioBStandin;
AT91S_PMC  PmcStandin;
AT91S_AIC  AicStandin;
