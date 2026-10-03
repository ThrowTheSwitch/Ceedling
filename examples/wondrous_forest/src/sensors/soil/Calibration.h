/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef SENSORS_SOIL_CALIBRATION_H
#define SENSORS_SOIL_CALIBRATION_H

/* Soil moisture reads as a percentage of saturation. */
int SoilCalibration_Apply(int raw);

#endif
