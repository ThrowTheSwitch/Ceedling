/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Three headers here all share the basename config.h -- drivers/config.h,
 * app/config.h (both subdirectories of this file's own directory), and
 * ../shared/config.h (reached only via a `..`-relative directive, resolving up
 * to src/shared/config.h). Every configured Ceedling search path already
 * covers each of their containing directories individually (src/** is
 * recursive), so a compile succeeding proves the generated Partial file's own
 * #include lines carried each one's real, disambiguating path -- collapsing
 * any two of the three to a bare "config.h" leaves at least one of
 * DRIVER_MAGIC/APP_MAGIC/SHARED_MAGIC undeclared, a guaranteed compile error
 * regardless of which file a bare, ambiguous "config.h" happened to resolve
 * to first. */

#include "sensor.h"
#include "drivers/config.h"
#include "app/config.h"
#include "../shared/config.h"

static int Sensor__ReadScaled(void)
{
    return SHARED_MAGIC * (DRIVER_MAGIC ^ APP_MAGIC);
}

int Sensor_ReadScaled(void) { return Sensor__ReadScaled(); }
