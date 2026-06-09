/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "unity.h"
#include "Types.h"
#include <math.h>

TEST_SOURCE_FILE("TemperatureCalculator.c")

extern float TemperatureCalculator_Calculate(uint16 val);

void setUp(void)
{
}

void tearDown(void)
{
}

void testTemperatureCalculatorShouldCalculateTemperatureFromMillivolts(void)
{
  float result;

  // Series resistor is 5k Ohms; Reference voltage is 3.0V
  // R(t) = A * e^(B*t); R is resistance of thermisor; t is temperature in C
  result = TemperatureCalculator_Calculate(1000);
  TEST_ASSERT_FLOAT_WITHIN(0.01f, 25.0f, result);

  result = TemperatureCalculator_Calculate(2985);
  TEST_ASSERT_FLOAT_WITHIN(0.01f, 68.317f, result);

  result = TemperatureCalculator_Calculate(3);
  TEST_ASSERT_FLOAT_WITHIN(0.01f, -19.96f, result);
}

void testShouldReturnNegativeInfinityWhen_0_millivoltsInput(void)
{
  TEST_ASSERT_FLOAT_IS_NEG_INF(TemperatureCalculator_Calculate(0));
}
