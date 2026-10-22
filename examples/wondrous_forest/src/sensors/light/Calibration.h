/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef SENSORS_LIGHT_CALIBRATION_H
#define SENSORS_LIGHT_CALIBRATION_H

/* Light intensity reads across a 10-bit ADC range. */
int LightCalibration_Apply(int raw);

#endif
