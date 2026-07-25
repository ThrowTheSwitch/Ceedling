/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

// Untested source with a syntax error -- fails to compile regardless of any
// :defines/:flags, deliberately triggering the :untested_sources guidance
// notice when :gcov :untested_sources is set to :compile.

int broken_uncovered_function(int a, int b) {
  return a + b // Missing semicolon and closing brace: guaranteed compile error.
