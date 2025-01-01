/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "example_file_call.h"
#include "example_file.h"

int call_add_numbers(int a, int b) {
  return add_numbers(a, b);
}
