/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */





#ifndef DRIVER
#define DRIVER

#include <stdint.h>

void driver_write(uint8_t val);
uint8_t driver_read();
void driver_init_device();

#endif /*include guard*/
