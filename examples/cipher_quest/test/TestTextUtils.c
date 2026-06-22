/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Tests for text_utils — core string operations.
 * No feature symbol required: text_utils is always compiled.
 * The TEST symbol (applied to all test files via the '*' matcher in project.yml)
 * is sufficient for this file. */

#include "unity.h"
#include "text_utils.h"

static char out[256];

void setUp(void)    { }
void tearDown(void) { }


/* --- text_reverse --- */

void test_Reverse_SimpleWord(void)
{
    text_reverse("hello", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("olleh", out);
}

void test_Reverse_EmptyString(void)
{
    text_reverse("", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("", out);
}

void test_Reverse_SingleChar(void)
{
    text_reverse("x", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("x", out);
}

void test_Reverse_PalindromeIsUnchanged(void)
{
    text_reverse("racecar", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("racecar", out);
}

void test_Reverse_PreservesSpaces(void)
{
    text_reverse("ab cd", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("dc ba", out);
}


/* --- text_to_upper --- */

void test_ToUpper_AllLowercase(void)
{
    text_to_upper("hello world", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("HELLO WORLD", out);
}

void test_ToUpper_AlreadyUpper(void)
{
    text_to_upper("HELLO", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("HELLO", out);
}

void test_ToUpper_Mixed(void)
{
    text_to_upper("hElLo", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("HELLO", out);
}

void test_ToUpper_NonAlphaUnchanged(void)
{
    text_to_upper("abc!123", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("ABC!123", out);
}


/* --- text_to_lower --- */

void test_ToLower_AllUppercase(void)
{
    text_to_lower("HELLO WORLD", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello world", out);
}

void test_ToLower_Mixed(void)
{
    text_to_lower("HeLLo", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello", out);
}


/* --- text_trim --- */

void test_Trim_LeadingSpaces(void)
{
    text_trim("   hello", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello", out);
}

void test_Trim_TrailingSpaces(void)
{
    text_trim("hello   ", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello", out);
}

void test_Trim_BothSides(void)
{
    text_trim("  hello world  ", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello world", out);
}

void test_Trim_NoSpaces(void)
{
    text_trim("hello", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("hello", out);
}

void test_Trim_OnlySpaces(void)
{
    text_trim("    ", out, sizeof(out));
    TEST_ASSERT_EQUAL_STRING("", out);
}


/* --- text_is_palindrome --- */

void test_IsPalindrome_SimpleTrue(void)
{
    TEST_ASSERT_TRUE(text_is_palindrome("racecar"));
}

void test_IsPalindrome_SimpleFalse(void)
{
    TEST_ASSERT_FALSE(text_is_palindrome("hello"));
}

void test_IsPalindrome_EmptyStringIsTrue(void)
{
    TEST_ASSERT_TRUE(text_is_palindrome(""));
}

void test_IsPalindrome_SingleChar(void)
{
    TEST_ASSERT_TRUE(text_is_palindrome("a"));
}

void test_IsPalindrome_CaseSensitive(void)
{
    /* text_is_palindrome is exact-character: 'A' != 'a' */
    TEST_ASSERT_FALSE(text_is_palindrome("Racecar"));
}


/* --- text_word_count --- */

void test_WordCount_SingleWord(void)
{
    TEST_ASSERT_EQUAL_INT(1, text_word_count("hello"));
}

void test_WordCount_MultipleWords(void)
{
    TEST_ASSERT_EQUAL_INT(3, text_word_count("one two three"));
}

void test_WordCount_EmptyString(void)
{
    TEST_ASSERT_EQUAL_INT(0, text_word_count(""));
}

void test_WordCount_OnlySpaces(void)
{
    TEST_ASSERT_EQUAL_INT(0, text_word_count("   "));
}

void test_WordCount_ExtraSpacesBetweenWords(void)
{
    TEST_ASSERT_EQUAL_INT(2, text_word_count("hello   world"));
}
