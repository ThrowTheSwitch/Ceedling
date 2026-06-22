/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "cipher.h"

#ifdef CIPHER_ROT13

void cipher_rot13(const char *input, char *output, size_t size)
{
    size_t i;

    if (size == 0) return;

    for (i = 0; i < size - 1 && input[i] != '\0'; i++)
    {
        char c = input[i];
        if      (c >= 'a' && c <= 'z') output[i] = (char)('a' + (c - 'a' + 13) % 26);
        else if (c >= 'A' && c <= 'Z') output[i] = (char)('A' + (c - 'A' + 13) % 26);
        else                            output[i] = c;
    }
    output[i] = '\0';
}

#endif /* CIPHER_ROT13 */


#ifdef CIPHER_CAESAR

void cipher_caesar_encrypt(const char *input, char *output, size_t size, int shift)
{
    size_t i;
    int s;

    if (size == 0) return;

    /* Normalize shift to 0-25, handling negative values cleanly */
    s = ((shift % 26) + 26) % 26;

    for (i = 0; i < size - 1 && input[i] != '\0'; i++)
    {
        char c = input[i];
        if      (c >= 'a' && c <= 'z') output[i] = (char)('a' + (c - 'a' + s) % 26);
        else if (c >= 'A' && c <= 'Z') output[i] = (char)('A' + (c - 'A' + s) % 26);
        else                            output[i] = c;
    }
    output[i] = '\0';
}

void cipher_caesar_decrypt(const char *input, char *output, size_t size, int shift)
{
    /* Decryption is encryption with the complementary shift */
    cipher_caesar_encrypt(input, output, size, 26 - ((shift % 26) + 26) % 26);
}

#endif /* CIPHER_CAESAR */
