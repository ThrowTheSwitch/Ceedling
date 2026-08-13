/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include <stdint.h>

#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

/* Left-shifting a value past its type's bit width is undefined behavior --
   UBSan's -fsanitize=undefined flags it at runtime without a real crash
   occurring at the OS level. */
void test_shift_overflow(void) {
  volatile uint8_t value = 128;
  volatile uint32_t result = value << 24;
  (void)result;
}
