/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Tests for cipher_rot13().
 *
 * This file requires the CIPHER_ROT13 symbol to be defined at compile time.
 * In project.yml the :defines :test: :TestCipherRot13: matcher supplies it,
 * so only this executable's build gets CIPHER_ROT13 — other test executables
 * are unaffected and cipher.c compiles without ROT13 for them.
 *
 * The same symbol is required for a release build; supply it via a mixin:
 *   ceedling release --mixin=mixin/release_rot13.yml */

#include "unity.h"
#include "cipher.h"

static char out[256];

void setUp(void)    { }
void tearDown(void) { }

void test_Rot13_EncodesLowercaseLetter(void)
{
    cipher_rot13("a", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("n", out);
}

void test_Rot13_EncodesUppercaseLetter(void)
{
    cipher_rot13("A", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("N", out);
}

void test_Rot13_WrapAroundLowercase(void)
{
    cipher_rot13("n", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("a", out);
}

void test_Rot13_WrapAroundUppercase(void)
{
    cipher_rot13("Z", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("M", out);
}

void test_Rot13_IsOwnInverse(void)
{
    char intermediate[256];
    cipher_rot13("Hello, Agent!", intermediate, sizeof(intermediate));
    cipher_rot13(intermediate, out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("Hello, Agent!", out);
}

void test_Rot13_NonAlphaUnchanged(void)
{
    cipher_rot13("123 !?", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("123 !?", out);
}

void test_Rot13_MixedSentence(void)
{
    cipher_rot13("Attack at dawn.", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("Nggnpx ng qnja.", out);
}

void test_Rot13_EmptyString(void)
{
    cipher_rot13("", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("", out);
}
