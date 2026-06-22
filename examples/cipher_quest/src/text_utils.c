/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "text_utils.h"

#include <string.h>
#include <ctype.h>

void text_reverse(const char *input, char *output, size_t size)
{
    size_t len = strlen(input);
    size_t i;

    if (size == 0) return;
    if (len >= size) len = size - 1;

    for (i = 0; i < len; i++)
    {
        output[i] = input[len - 1 - i];
    }
    output[len] = '\0';
}

void text_to_upper(const char *input, char *output, size_t size)
{
    size_t i;

    if (size == 0) return;

    for (i = 0; i < size - 1 && input[i] != '\0'; i++)
    {
        output[i] = (char)toupper((unsigned char)input[i]);
    }
    output[i] = '\0';
}

void text_to_lower(const char *input, char *output, size_t size)
{
    size_t i;

    if (size == 0) return;

    for (i = 0; i < size - 1 && input[i] != '\0'; i++)
    {
        output[i] = (char)tolower((unsigned char)input[i]);
    }
    output[i] = '\0';
}

void text_trim(const char *input, char *output, size_t size)
{
    size_t start = 0;
    size_t len;
    size_t end;
    size_t out_len;

    if (size == 0) return;

    while (input[start] == ' '  || input[start] == '\t' ||
           input[start] == '\n' || input[start] == '\r')
    {
        start++;
    }

    len = strlen(input);
    end = len;

    while (end > start && (input[end - 1] == ' '  || input[end - 1] == '\t' ||
                            input[end - 1] == '\n' || input[end - 1] == '\r'))
    {
        end--;
    }

    out_len = end - start;
    if (out_len >= size) out_len = size - 1;

    memcpy(output, input + start, out_len);
    output[out_len] = '\0';
}

bool text_is_palindrome(const char *input)
{
    size_t len = strlen(input);
    size_t i;

    for (i = 0; i < len / 2; i++)
    {
        if (input[i] != input[len - 1 - i]) return false;
    }
    return true;
}

int text_word_count(const char *input)
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
