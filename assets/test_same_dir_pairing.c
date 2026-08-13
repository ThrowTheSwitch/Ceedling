/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

// `same_dir_pairing_other.h` transitively includes `same_dir_pairing_module.h` (types
// only), which shares a filename stem with `same_dir_pairing_module.c` -- the same
// source file that implements the differently-named header mocked below. Auto
// source-pairing must not pull that real source file into this build alongside its mock.

#include "unity.h"
#include "mock_same_dir_pairing_module_func.h"
#include "same_dir_pairing_other.h"

void setUp(void) {}
void tearDown(void) {}

void test_SameDirPairingOtherThing_should_not_explode(void) {
  SameDirPairingOtherThing();
  TEST_PASS();
}
