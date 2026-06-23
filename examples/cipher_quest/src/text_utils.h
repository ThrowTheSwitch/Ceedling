/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef TEXT_UTILS_H
#define TEXT_UTILS_H

#include <stddef.h>
#include <stdbool.h>

/* Core string utilities — always compiled, no feature symbol required. */

void text_reverse(const char *input, char *output, size_t size);
void text_to_upper(const char *input, char *output, size_t size);
void text_to_lower(const char *input, char *output, size_t size);
void text_trim(const char *input, char *output, size_t size);
bool text_is_palindrome(const char *input);
int  text_word_count(const char *input);

#endif /* TEXT_UTILS_H */
