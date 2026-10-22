/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Deliberately empty of real instructions -- this file exists only to prove
   Ceedling discovers and compiles an uppercase `.S` assembly file alongside
   a lowercase `.s` sibling under one shared :extension -> :assembly setting. */

.globl asm_helper_upper_marker
asm_helper_upper_marker:
