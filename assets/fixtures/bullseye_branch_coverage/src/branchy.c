/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Deliberately and only partially covered by test_branchy.c. Exactly one of two
   functions is exercised, and only one decision outcome within it. That yields
   stable, predictable coverage percentages for Bullseye branch detail and
   coverage threshold system tests. */

#include "branchy.h"

int branchy_classify(int n) {
  if (n > 10) { return 1; }
  else if (n < 0) { return -1; }
  return 0;
}

int branchy_unused(int a, int b) {
  if (a && b) { return 1; }
  return 0;
}
