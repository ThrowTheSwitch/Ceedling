/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "example_file_with_stdio.h"

void print_number(FILE *f, int n)
{
  fprintf(f, "%d\n", n);
}
