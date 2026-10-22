/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "sensors/soil/Calibration.h"

/* Private to this module. The light sensor's own calibration has a clamp of its
 * own with a different ceiling, which is what makes the two modules worth
 * telling apart. */
static int Soil__Clamp(int value)
{
  if (value < 0)   { return 0; }
  if (value > 100) { return 100; }
  return value;
}

int SoilCalibration_Apply(int raw)
{
  return Soil__Clamp(raw / 10);
}
