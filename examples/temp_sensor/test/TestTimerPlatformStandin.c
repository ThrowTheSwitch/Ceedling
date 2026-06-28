/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/*
 * Off-platform tests for Timer hardware configuration and interrupt handling.
 *
 * These tests compile and exercise the real production source files
 * (TimerConfigurator.c, TimerInterruptConfigurator.c, TimerInterruptHandler.c)
 * against the platform standin defined in test/platform/at91sam7s256.h.
 * No mocks are involved.
 *
 * setUp() resets all four timer-related standin structs to all-zeros and
 * calls Timer_SetSystemTime(0) before each test, providing a clean starting
 * state. Tests for Timer_InterruptHandler set TC_SR within the test to
 * exercise the CPCS flag gating behavior.
 */

#include "unity.h"
#include "Types.h"
#include "at91sam7s256.h"
#include "TimerConfigurator.h"
#include "TimerInterruptConfigurator.h"
#include "TimerInterruptHandler.h"
#include <string.h>

void setUp(void)
{
  memset(&TimerStandin, 0, sizeof(TimerStandin));
  memset(&PioBStandin,  0, sizeof(PioBStandin));
  memset(&PmcStandin,   0, sizeof(PmcStandin));
  memset(&AicStandin,   0, sizeof(AicStandin));
  Timer_SetSystemTime(0);
}

void tearDown(void) { }

/* -------------------------------------------------------------------------
 * TimerConfigurator — peripheral clock and reset
 * ------------------------------------------------------------------------- */

void testEnablePeripheralClocksWritesTimer0AndPioBBitsToPMC(void)
{
  Timer_EnablePeripheralClocks();
  TEST_ASSERT_EQUAL_UINT32(TIMER0_CLOCK_ENABLE | PIOB_CLOCK_ENABLE,
                            PmcStandin.PMC_PCER);
}

void testResetDisablesTimerClockViaClockControlRegister(void)
{
  Timer_Reset();
  TEST_ASSERT_EQUAL_UINT32(AT91C_TC_CLKDIS, TimerStandin.TC_CCR);
}

void testResetMasksAllInterruptsViaInterruptDisableRegister(void)
{
  Timer_Reset();
  TEST_ASSERT_EQUAL_UINT32(0xffffffff, TimerStandin.TC_IDR);
}

/* -------------------------------------------------------------------------
 * TimerConfigurator — waveform mode and period
 * ------------------------------------------------------------------------- */

void testConfigureModeWritesWaveformSettingsToChannelModeRegister(void)
{
  Timer_ConfigureMode();

  /* ACPC=toggle TIOA on RC compare; WAVE mode; UP with auto-trigger on RC;
   * clock source = MCK/1024                                                   */
  TEST_ASSERT_EQUAL_UINT32(0x000CC004, TimerStandin.TC_CMR);
}

void testConfigurePeriodWrites10msPeriodValueToRegisterC(void)
{
  Timer_ConfigurePeriod();

  /* 469 ticks at MCK/1024 with MCK=48054857 ≈ 10 ms                          */
  TEST_ASSERT_EQUAL_UINT32(469, TimerStandin.TC_RC);
}

/* -------------------------------------------------------------------------
 * TimerConfigurator — output pin and clock start
 * ------------------------------------------------------------------------- */

void testEnableOutputPinReleasesTimerPinFromGpioOnPioB(void)
{
  Timer_EnableOutputPin();
  TEST_ASSERT_EQUAL_UINT32(TIOA0_PIN_MASK, PioBStandin.PIO_PDR);
}

void testEnableWritesClockEnableBitToClockControlRegister(void)
{
  Timer_Enable();
  TEST_ASSERT_EQUAL_UINT32(AT91C_TC_CLKEN, TimerStandin.TC_CCR);
}

void testStartWritesSoftwareTriggerBitToClockControlRegister(void)
{
  Timer_Start();
  TEST_ASSERT_EQUAL_UINT32(AT91C_TC_SWTRG, TimerStandin.TC_CCR);
}

/* -------------------------------------------------------------------------
 * TimerInterruptConfigurator — AIC enable/disable
 * ------------------------------------------------------------------------- */

void testDisableInterruptWritesTimer0MaskToAicIdcr(void)
{
  Timer_DisableInterrupt();
  TEST_ASSERT_EQUAL_UINT32(TIMER0_ID_MASK, AicStandin.AIC_IDCR);
}

void testEnableInterruptWritesTimer0MaskToAicIecr(void)
{
  Timer_EnableInterrupt();
  TEST_ASSERT_EQUAL_UINT32(TIMER0_ID_MASK, AicStandin.AIC_IECR);
}

/* -------------------------------------------------------------------------
 * TimerInterruptHandler — RC compare gating
 *
 * Timer_InterruptHandler() reads TC_SR and increments the system time by
 * 10 ms only when the CPCS (RC compare) bit is set. These tests exercise
 * that branch without needing a real interrupt to fire.
 * ------------------------------------------------------------------------- */

void testInterruptHandlerIncrementsSystemTimeBy10WhenCpcsFlagIsSet(void)
{
  TimerStandin.TC_SR = AT91C_TC_CPCS;
  Timer_InterruptHandler();
  TEST_ASSERT_EQUAL_UINT32(10, Timer_GetSystemTime());
}

void testInterruptHandlerDoesNotChangeSystemTimeWhenCpcsFlagIsClear(void)
{
  TimerStandin.TC_SR = 0x00;
  Timer_InterruptHandler();
  TEST_ASSERT_EQUAL_UINT32(0, Timer_GetSystemTime());
}

void testInterruptHandlerAccumulatesSystemTimeAcrossMultipleCalls(void)
{
  TimerStandin.TC_SR = AT91C_TC_CPCS;

  Timer_InterruptHandler();
  Timer_InterruptHandler();
  Timer_InterruptHandler();

  TEST_ASSERT_EQUAL_UINT32(30, Timer_GetSystemTime());
}
