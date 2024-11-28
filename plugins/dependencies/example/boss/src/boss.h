/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef BOSS_H
#define BOSS_H

void boss_start();
void boss_hire_workers(int num_workers);
void boss_fire_workers(int num_workers);
int boss_micro_manage(int* chunks_of_work, int num_chunks);

#endif 
