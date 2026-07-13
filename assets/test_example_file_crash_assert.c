/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include <assert.h>
#include "unity.h"
#include "example_file.h"


void setUp(void) {}
void tearDown(void) {}

void test_add_numbers_adds_numbers(void) {
  TEST_ASSERT_EQUAL_INT(2, add_numbers(1,1));
}

void test_add_numbers_triggers_assert(void) {
  // assert(0) triggers SIGABRT via glibc's assertion handler,
  // which writes a diagnostic message to stderr before aborting.
  // This exercises the issue #1038 scenario: stderr output surfaced in crash reports.
  assert(0);
}
