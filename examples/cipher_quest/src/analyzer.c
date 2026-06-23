/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "analyzer.h"

#ifdef ANALYZER_ENABLED

#include <string.h>
#include <ctype.h>

int analyzer_char_count(const char *input)
{
    return (int)strlen(input);
}

int analyzer_word_count(const char *input)
{
    int count = 0;
    bool in_word = false;
    size_t i;

    for (i = 0; input[i] != '\0'; i++)
    {
        if (input[i] != ' ' && input[i] != '\t' && input[i] != '\n' && input[i] != '\r')
        {
            if (!in_word)
            {
                count++;
                in_word = true;
            }
        }
        else
        {
            in_word = false;
        }
    }
    return count;
}

void analyzer_char_frequency(const char *input, int freq[26])
{
    size_t i;

    memset(freq, 0, 26 * sizeof(int));

    for (i = 0; input[i] != '\0'; i++)
    {
        if (isalpha((unsigned char)input[i]))
        {
            freq[tolower((unsigned char)input[i]) - 'a']++;
        }
    }
}

bool analyzer_is_palindrome(const char *input)
{
    char filtered[512];
    size_t j = 0;
    size_t i;
    size_t len;

    for (i = 0; input[i] != '\0' && j < sizeof(filtered) - 1; i++)
    {
        if (isalpha((unsigned char)input[i]))
        {
            filtered[j++] = (char)tolower((unsigned char)input[i]);
        }
    }
    filtered[j] = '\0';
    len = j;

    for (i = 0; i < len / 2; i++)
    {
        if (filtered[i] != filtered[len - 1 - i]) return false;
    }
    return true;
}

#endif /* ANALYZER_ENABLED */
