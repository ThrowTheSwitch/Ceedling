/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TemperatureFilter.h"
#include <math.h>

static bool initialized;
static float temperatureInCelcius;

void TemperatureFilter_Init(void)
{
  initialized = FALSE;
  temperatureInCelcius = -INFINITY;
}

float TemperatureFilter_GetTemperatureInCelcius(void)
{
  return temperatureInCelcius;
}

void TemperatureFilter_ProcessInput(float temperature)
{
  if (!initialized)
  {
    temperatureInCelcius = temperature;
    initialized = TRUE;
  }
  else
  {
    if (temperature == +INFINITY ||
        temperature == -INFINITY ||
        isnan(temperature))
    {
      initialized = FALSE;
      temperature = -INFINITY;
    }
    
    temperatureInCelcius = (temperatureInCelcius * 0.75f) + (temperature * 0.25);
  }
}
