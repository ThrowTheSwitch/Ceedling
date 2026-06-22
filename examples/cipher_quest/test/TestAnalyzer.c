/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Tests for analyzer functions.
 *
 * This file requires the ANALYZER_ENABLED symbol to be defined at compile time.
 * In project.yml the :defines :test: :TestAnalyzer: matcher supplies it,
 * so only this executable's build gets ANALYZER_ENABLED.
 *
 * Supply ANALYZER_ENABLED for a release build via a mixin:
 *   ceedling release --mixin=mixin/release_analyze.yml
 *
 * Note: analyzer_is_palindrome() differs from text_is_palindrome() —
 * it strips non-letter characters and ignores case, making it suitable
 * for natural-language palindrome detection. */

#include "unity.h"
#include "analyzer.h"

void setUp(void)    { }
void tearDown(void) { }


/* --- analyzer_char_count --- */

void test_CharCount_EmptyString(void)
{
    TEST_ASSERT_EQUAL_INT(0, analyzer_char_count(""));
}

void test_CharCount_SingleChar(void)
{
    TEST_ASSERT_EQUAL_INT(1, analyzer_char_count("x"));
}

void test_CharCount_IncludesSpaces(void)
{
    TEST_ASSERT_EQUAL_INT(11, analyzer_char_count("hello world"));
}


/* --- analyzer_word_count --- */

void test_WordCount_SingleWord(void)
{
    TEST_ASSERT_EQUAL_INT(1, analyzer_word_count("mission"));
}

void test_WordCount_MultipleWords(void)
{
    TEST_ASSERT_EQUAL_INT(4, analyzer_word_count("your mission if accepted"));
}

void test_WordCount_EmptyString(void)
{
    TEST_ASSERT_EQUAL_INT(0, analyzer_word_count(""));
}


/* --- analyzer_char_frequency --- */

void test_CharFrequency_SingleLetter(void)
{
    int freq[26];
    analyzer_char_frequency("a", freq);
    TEST_ASSERT_EQUAL_INT(1, freq[0]);  /* 'a' */
}

void test_CharFrequency_CountsCorrectly(void)
{
    int freq[26];
    analyzer_char_frequency("aabbc", freq);
    TEST_ASSERT_EQUAL_INT(2, freq[0]);  /* 'a' */
    TEST_ASSERT_EQUAL_INT(2, freq[1]);  /* 'b' */
    TEST_ASSERT_EQUAL_INT(1, freq[2]);  /* 'c' */
    TEST_ASSERT_EQUAL_INT(0, freq[3]);  /* 'd' — not present */
}

void test_CharFrequency_CaseInsensitive(void)
{
    int freq[26];
    analyzer_char_frequency("AaBb", freq);
    TEST_ASSERT_EQUAL_INT(2, freq[0]);  /* 'a'+'A' counted together */
    TEST_ASSERT_EQUAL_INT(2, freq[1]);  /* 'b'+'B' counted together */
}

void test_CharFrequency_IgnoresNonAlpha(void)
{
    int freq[26];
    int i;
    analyzer_char_frequency("123 !?", freq);
    for (i = 0; i < 26; i++)
    {
        TEST_ASSERT_EQUAL_INT(0, freq[i]);
    }
}


/* --- analyzer_is_palindrome --- */

void test_IsPalindrome_SimpleWord(void)
{
    TEST_ASSERT_TRUE(analyzer_is_palindrome("racecar"));
}

void test_IsPalindrome_NotAPalindrome(void)
{
    TEST_ASSERT_FALSE(analyzer_is_palindrome("hello"));
}

void test_IsPalindrome_CaseInsensitive(void)
{
    TEST_ASSERT_TRUE(analyzer_is_palindrome("Racecar"));
}

void test_IsPalindrome_IgnoresSpaces(void)
{
    TEST_ASSERT_TRUE(analyzer_is_palindrome("A man a plan a canal Panama"));
}

void test_IsPalindrome_IgnoresPunctuation(void)
{
    TEST_ASSERT_TRUE(analyzer_is_palindrome("Was it a car or a cat I saw?"));
}

void test_IsPalindrome_EmptyStringIsTrue(void)
{
    TEST_ASSERT_TRUE(analyzer_is_palindrome(""));
}
