/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "example_file_with_stdio.h"

void setUp(void) {}
void tearDown(void) {}

void test_print_number(void)
{
  print_number(stdout, 42);
  TEST_PASS();
}
