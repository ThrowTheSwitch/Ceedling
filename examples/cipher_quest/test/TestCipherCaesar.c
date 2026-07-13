/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Tests for cipher_caesar_encrypt() and cipher_caesar_decrypt().
 *
 * This file requires the CIPHER_CAESAR symbol to be defined at compile time.
 * In project.yml the :defines :test: :TestCipherCaesar: matcher supplies it,
 * so only this executable's build gets CIPHER_CAESAR — CIPHER_ROT13 tests
 * remain isolated in their own executable.
 *
 * Supply CIPHER_CAESAR for a release build via a mixin:
 *   ceedling release --mixin=mixin/release_caesar.yml */

#include "unity.h"
#include "cipher.h"

static char out[256];

void setUp(void)    { }
void tearDown(void) { }

void test_CaesarEncrypt_ShiftByThree(void)
{
    cipher_caesar_encrypt("ABC", out, sizeof(out), 3);
    TEST_ASSERT_EQUAL_STRING("DEF", out);
}

void test_CaesarEncrypt_LowercaseShiftByThree(void)
{
    cipher_caesar_encrypt("abc", out, sizeof(out), 3);
    TEST_ASSERT_EQUAL_STRING("def", out);
}

void test_CaesarEncrypt_WrapAround(void)
{
    cipher_caesar_encrypt("xyz", out, sizeof(out), 3);
    TEST_ASSERT_EQUAL_STRING("abc", out);
}

void test_CaesarEncrypt_ShiftByZero(void)
{
    cipher_caesar_encrypt("hello", out, sizeof(out), 0);
    TEST_ASSERT_EQUAL_STRING("hello", out);
}

void test_CaesarEncrypt_NonAlphaUnchanged(void)
{
    cipher_caesar_encrypt("Hello, World!", out, sizeof(out), 13);
    TEST_ASSERT_EQUAL_STRING("Uryyb, Jbeyq!", out);
}

void test_CaesarDecrypt_ShiftByThree(void)
{
    cipher_caesar_decrypt("DEF", out, sizeof(out), 3);
    TEST_ASSERT_EQUAL_STRING("ABC", out);
}

void test_CaesarDecrypt_WrapAround(void)
{
    cipher_caesar_decrypt("abc", out, sizeof(out), 3);
    TEST_ASSERT_EQUAL_STRING("xyz", out);
}

void test_CaesarRoundTrip_FullSentence(void)
{
    char encrypted[256];
    cipher_caesar_encrypt("The quick brown fox", encrypted, sizeof(encrypted), 7);
    cipher_caesar_decrypt(encrypted, out, sizeof(out), 7);
    TEST_ASSERT_EQUAL_STRING("The quick brown fox", out);
}

void test_CaesarEncrypt_NegativeShiftNormalized(void)
{
    /* Shift of -3 is equivalent to shift of 23 */
    cipher_caesar_encrypt("DEF", out, sizeof(out), -3);
    TEST_ASSERT_EQUAL_STRING("ABC", out);
}
