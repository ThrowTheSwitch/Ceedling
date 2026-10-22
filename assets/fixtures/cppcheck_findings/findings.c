/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Deliberately defective. Cppcheck reports the double free at error severity,
   which gives the :fail_build system and integration tests a stable finding to
   assert against. */

#include "findings.h"
#include <stdlib.h>

int findings_double_free(void) {
  int *p = malloc(sizeof(int));
  if (p == NULL) { return -1; }
  *p = 7;
  int value = *p;
  free(p);
  free(p);
  return value;
}
