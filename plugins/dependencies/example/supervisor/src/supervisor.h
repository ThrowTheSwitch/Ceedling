/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef SUPERVISOR_H
#define SUPERVISOR_H

int supervisor_delegate(int* worker_loads, int num_workers);
int supervisor_progress(int* worker_loads, int num_workers);

#endif 
