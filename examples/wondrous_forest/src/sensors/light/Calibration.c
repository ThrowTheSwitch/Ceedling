/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "sensors/light/Calibration.h"

/* Private to this module -- see the soil sensor's own clamp. */
static int Light__Clamp(int value)
{
  if (value < 0)    { return 0; }
  if (value > 1023) { return 1023; }
  return value;
}

int LightCalibration_Apply(int raw)
{
  return Light__Clamp(raw * 4);
}
