/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* widget.c includes this wrapper directly; nested_extra.h is only ever
 * reached transitively through it, never named directly by widget.c. */

#ifndef NESTED_WRAPPER_H
#define NESTED_WRAPPER_H

#include "nested_extra.h"

#endif // NESTED_WRAPPER_H
