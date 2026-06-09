/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "TemperatureCalculator.h"
#include <math.h>

#ifndef logl
#define logl log
#endif

#ifndef SUPPLY_VOLTAGE
#define SUPPLY_VOLTAGE 5.0
#endif

float TemperatureCalculator_Calculate(uint16 millivolts)
{
  const double supply_voltage = SUPPLY_VOLTAGE;
  const double series_resistance = 5000;
  const double coefficient_A = 316589.698;
  const double coefficient_B = -0.1382009;
  double sensor_voltage = ((double)millivolts / 1000);
  double resistance;
  
  if (millivolts == 0)
  {
    return -INFINITY;
  }

  // Series resistor is 5k Ohms; Reference voltage is 3.0V
  // R(t) = A * e^(B*t); R is resistance of thermisor; t is temperature in C
  resistance = ((supply_voltage * series_resistance) / sensor_voltage) - series_resistance;
  return (float)(logl(resistance / coefficient_A) / coefficient_B);
}
