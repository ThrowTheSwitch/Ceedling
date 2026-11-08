/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef FOREST_UNITS_H
#define FOREST_UNITS_H

#include "Types.h"

/* Unit conversions shared across the station, written as C99 inline functions.
 * Every caller sees the body and may inline it. An unoptimized call links to an
 * external definition instead. C99 places that definition in the one source file
 * that declares the function `extern inline`. This header has no source file of
 * its own, so RainGauge.c holds the definition. */
inline uint32 ForestUnits_MicrometersToTenthsMm(uint32 micrometers)
{
    return micrometers / 100u;
}

#endif /* FOREST_UNITS_H */
