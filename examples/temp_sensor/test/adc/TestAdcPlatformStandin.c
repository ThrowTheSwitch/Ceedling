/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/*
 * Off-platform tests for ADC hardware configuration and sensor reading.
 *
 * These tests compile and exercise the real production source files
 * (AdcHardwareConfigurator.c, AdcTemperatureSensor.c) against the platform
 * standin defined in test/platform/at91sam7s256.h. No mocks are involved.
 *
 * setUp() resets the ADC standin struct to all-zeros before each test, so
 * any register field that a test finds non-zero was written there by the
 * production code under test.
 */

#include "unity.h"
#include "Types.h"
#include "at91sam7s256.h"
#include "AdcHardwareConfigurator.h"
#include "AdcTemperatureSensor.h"
#include <string.h>

void setUp(void)
{
  memset(&AdcStandin, 0, sizeof(AdcStandin));
}

void tearDown(void) { }

/* -------------------------------------------------------------------------
 * AdcHardwareConfigurator
 * ------------------------------------------------------------------------- */

void testResetWritesSwrstBitToControlRegister(void)
{
  Adc_Reset();
  TEST_ASSERT_EQUAL_UINT32(AT91C_ADC_SWRST, AdcStandin.ADC_CR);
}

void testConfigureModeWritesPrescalerAndSampleHoldTime(void)
{
  Adc_ConfigureMode();

  /* Prescaler value 11 in bits [15:8]; sample-hold time 4 in bits [23:16] */
  TEST_ASSERT_EQUAL_UINT32((((uint32)11) << 8) | (((uint32)4) << 16),
                            AdcStandin.ADC_MR);
}

void testEnableTemperatureChannelSetsChannel4EnableBit(void)
{
  Adc_EnableTemperatureChannel();
  TEST_ASSERT_EQUAL_UINT32(0x10, AdcStandin.ADC_CHER);
}

/* -------------------------------------------------------------------------
 * AdcTemperatureSensor
 * ------------------------------------------------------------------------- */

void testStartConversionWritesStartBitToControlRegister(void)
{
  Adc_StartTemperatureSensorConversion();
  TEST_ASSERT_EQUAL_UINT32(AT91C_ADC_START, AdcStandin.ADC_CR);
}

void testSampleReadyReturnsFalseWhenEoc4BitIsClear(void)
{
  AdcStandin.ADC_SR = 0x00;
  TEST_ASSERT_FALSE(Adc_TemperatureSensorSampleReady());
}

void testSampleReadyReturnsTrueWhenEoc4BitIsSet(void)
{
  AdcStandin.ADC_SR = AT91C_ADC_EOC4;
  TEST_ASSERT_TRUE(Adc_TemperatureSensorSampleReady());
}

void testSampleReadyIgnoresOtherStatusBitsAndOnlyChecksEoc4(void)
{
  /* All status bits set except EOC4 */
  AdcStandin.ADC_SR = ~AT91C_ADC_EOC4;
  TEST_ASSERT_FALSE(Adc_TemperatureSensorSampleReady());
}

void testReadTemperatureSensorConvertsAdcCountsToMillivolts(void)
{
  /* ADC counts → picovolts: counts × 2929688 pV/count (3.0V ref / 1024 counts)
   * 1000 counts × 2929688 = 2929688000 pV → +0.5mV rounding → 2930 mV        */
  AdcStandin.ADC_CDR4 = 1000;
  TEST_ASSERT_EQUAL_UINT16(2930, Adc_ReadTemperatureSensor());
}

void testReadTemperatureSensorReturnsZeroForZeroCounts(void)
{
  AdcStandin.ADC_CDR4 = 0;
  TEST_ASSERT_EQUAL_UINT16(0, Adc_ReadTemperatureSensor());
}
