/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef CIPHER_H
#define CIPHER_H

#include <stddef.h>

/* Cipher operations — each function group guarded by its own feature symbol.
 * CIPHER_ROT13 and CIPHER_CAESAR are independent; both may be defined together.
 * Supply one or both via a mixin to include in a release build. */

#ifdef CIPHER_ROT13
/* ROT13 is its own inverse: encode and decode are the same operation. */
void cipher_rot13(const char *input, char *output, size_t size);
#endif

#ifdef CIPHER_CAESAR
void cipher_caesar_encrypt(const char *input, char *output, size_t size, int shift);
void cipher_caesar_decrypt(const char *input, char *output, size_t size, int shift);
#endif

#endif /* CIPHER_H */
