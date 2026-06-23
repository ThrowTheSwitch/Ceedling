/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* CLI entry point — this file is NOT unit tested.
 * Unit tests target text_utils, cipher, and analyzer directly. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "text_utils.h"
#include "cipher.h"
#include "analyzer.h"

/* Compile-time guard: at least one feature symbol must be defined for a
 * useful release build. Feature symbols are supplied via a mixin file or
 * an inline-YAML mixin string. Without one, the build fails here with a
 * clear message rather than producing a binary with no agent capabilities.
 *
 * See the mixin/ directory and project README for usage details. */
#if !defined(CIPHER_ROT13) && !defined(CIPHER_CAESAR) && !defined(ANALYZER_ENABLED)
#error "cipher_quest: No feature defined. An agent needs tools. Supply a mixin providing at least one of: CIPHER_ROT13, CIPHER_CAESAR, ANALYZER_ENABLED"
#endif

#define OUTPUT_SIZE 1024

static void print_usage(void)
{
    printf("Usage: cipher_quest <command> [args...]\n\n");
    printf("Core commands (always available):\n");
    printf("  reverse <text>             Reverse the characters\n");
    printf("  upper <text>               Convert to uppercase\n");
    printf("  lower <text>               Convert to lowercase\n");
    printf("  trim <text>                Strip leading/trailing whitespace\n");
    printf("  palindrome <text>          Simple palindrome check (exact characters)\n");
    printf("  wordcount <text>           Count words\n");
#ifdef CIPHER_ROT13
    printf("\nCipher: ROT13\n");
    printf("  rot13 <text>               Encode or decode (ROT13 is its own inverse)\n");
#endif
#ifdef CIPHER_CAESAR
    printf("\nCipher: Caesar\n");
    printf("  caesar <shift> <text>      Encrypt with Caesar cipher\n");
    printf("  uncaesar <shift> <text>    Decrypt with Caesar cipher\n");
#endif
#ifdef ANALYZER_ENABLED
    printf("\nAnalysis:\n");
    printf("  charcount <text>           Count total characters\n");
    printf("  frequency <text>           Show letter frequency table\n");
    printf("  ispalindrome <text>        Palindrome check (ignores case and non-letters)\n");
#endif
}

int main(int argc, char *argv[])
{
    char output[OUTPUT_SIZE];
    const char *cmd;
    const char *text;

    if (argc < 3)
    {
        print_usage();
        return 1;
    }

    cmd  = argv[1];
    text = argv[argc - 1];

    if (strcmp(cmd, "reverse") == 0)
    {
        text_reverse(text, output, OUTPUT_SIZE);
        printf("%s\n", output);
    }
    else if (strcmp(cmd, "upper") == 0)
    {
        text_to_upper(text, output, OUTPUT_SIZE);
        printf("%s\n", output);
    }
    else if (strcmp(cmd, "lower") == 0)
    {
        text_to_lower(text, output, OUTPUT_SIZE);
        printf("%s\n", output);
    }
    else if (strcmp(cmd, "trim") == 0)
    {
        text_trim(text, output, OUTPUT_SIZE);
        printf("[%s]\n", output);
    }
    else if (strcmp(cmd, "palindrome") == 0)
    {
        printf("%s\n", text_is_palindrome(text) ? "Yes, it is a palindrome."
                                                 : "No, it is not a palindrome.");
    }
    else if (strcmp(cmd, "wordcount") == 0)
    {
        printf("%d word(s)\n", text_word_count(text));
    }
#ifdef CIPHER_ROT13
    else if (strcmp(cmd, "rot13") == 0)
    {
        cipher_rot13(text, output, OUTPUT_SIZE);
        printf("%s\n", output);
    }
#endif
#ifdef CIPHER_CAESAR
    else if (strcmp(cmd, "caesar") == 0 && argc == 4)
    {
        cipher_caesar_encrypt(text, output, OUTPUT_SIZE, atoi(argv[2]));
        printf("%s\n", output);
    }
    else if (strcmp(cmd, "uncaesar") == 0 && argc == 4)
    {
        cipher_caesar_decrypt(text, output, OUTPUT_SIZE, atoi(argv[2]));
        printf("%s\n", output);
    }
#endif
#ifdef ANALYZER_ENABLED
    else if (strcmp(cmd, "charcount") == 0)
    {
        printf("%d character(s)\n", analyzer_char_count(text));
    }
    else if (strcmp(cmd, "frequency") == 0)
    {
        int freq[26];
        int i;
        analyzer_char_frequency(text, freq);
        printf("Letter frequency:\n");
        for (i = 0; i < 26; i++)
        {
            if (freq[i] > 0) printf("  %c: %d\n", 'a' + i, freq[i]);
        }
    }
    else if (strcmp(cmd, "ispalindrome") == 0)
    {
        printf("%s\n", analyzer_is_palindrome(text) ? "Yes, it is a palindrome."
                                                     : "No, it is not a palindrome.");
    }
#endif
    else
    {
        fprintf(stderr, "Unknown command: %s\n\n", cmd);
        print_usage();
        return 1;
    }

    return 0;
}
