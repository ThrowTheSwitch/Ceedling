/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef ANALYZER_H
#define ANALYZER_H

#include <stdbool.h>

/* Text analysis functions — all guarded by ANALYZER_ENABLED.
 * Supply this symbol via a mixin to include in a release build.
 *
 * Unlike the simpler text_is_palindrome() in text_utils, analyzer_is_palindrome()
 * ignores non-alphabetic characters and is case-insensitive, making it suitable
 * for natural-language palindrome checking ("A man a plan a canal Panama"). */

#ifdef ANALYZER_ENABLED

int  analyzer_char_count(const char *input);
int  analyzer_word_count(const char *input);
void analyzer_char_frequency(const char *input, int freq[26]);
bool analyzer_is_palindrome(const char *input);

#endif /* ANALYZER_ENABLED */

#endif /* ANALYZER_H */
