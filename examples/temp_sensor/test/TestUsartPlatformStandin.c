/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/*
 * Off-platform tests for USART hardware configuration and character output.
 *
 * These tests compile and exercise the real production source files
 * (UsartConfigurator.c, UsartTransmitBufferStatus.c, UsartPutChar.c)
 * against the platform standin defined in test/platform/at91sam7s256.h.
 * No mocks are involved.
 *
 * setUp() resets all three USART-related standin structs to all-zeros before
 * each test. Tests that need a specific pre-condition (such as TXRDY set so
 * Usart_PutChar does not spin) configure the standin within the test itself
 * after setUp has provided the clean baseline.
 */

#include "unity.h"
#include "Types.h"
#include "at91sam7s256.h"
#include "UsartConfigurator.h"
#include "UsartTransmitBufferStatus.h"
#include "UsartPutChar.h"
#include <string.h>

void setUp(void)
{
  memset(&UsartStandin, 0, sizeof(UsartStandin));
  memset(&PioAStandin,  0, sizeof(PioAStandin));
  memset(&PmcStandin,   0, sizeof(PmcStandin));
}

void tearDown(void) { }

/* -------------------------------------------------------------------------
 * UsartConfigurator — I/O pin and peripheral clock setup
 * ------------------------------------------------------------------------- */

void testConfigureUsartIoSelectsTxPinForPeripheralA(void)
{
  Usart_ConfigureUsartIO();
  TEST_ASSERT_EQUAL_UINT32(USART0_TX_PIN, PioAStandin.PIO_ASR);
}

void testConfigureUsartIoClearsPeripheralBSelection(void)
{
  Usart_ConfigureUsartIO();
  TEST_ASSERT_EQUAL_UINT32(0, PioAStandin.PIO_BSR);
}

void testConfigureUsartIoDisablesGpioControlForTxPin(void)
{
  Usart_ConfigureUsartIO();
  TEST_ASSERT_EQUAL_UINT32(USART0_TX_PIN, PioAStandin.PIO_PDR);
}

void testEnablePeripheralClockWritesUsart0BitToPmc(void)
{
  Usart_EnablePeripheralClock();
  TEST_ASSERT_EQUAL_UINT32(((uint32)1) << USART0_CLOCK_ENABLE, PmcStandin.PMC_PCER);
}

/* -------------------------------------------------------------------------
 * UsartConfigurator — USART peripheral reset and mode configuration
 * ------------------------------------------------------------------------- */

void testResetDisablesAllInterrupts(void)
{
  Usart_Reset();
  TEST_ASSERT_EQUAL_UINT32(0xffffffff, UsartStandin.US_IDR);
}

void testResetWritesResetAndDisableBitsToControlRegister(void)
{
  Usart_Reset();
  TEST_ASSERT_EQUAL_UINT32(AT91C_US_RSTRX | AT91C_US_RSTTX |
                            AT91C_US_RXDIS | AT91C_US_TXDIS,
                            UsartStandin.US_CR);
}

void testConfigureModeWritesCorrectFormatBitsToModeRegister(void)
{
  Usart_ConfigureMode();

  /* Normal mode, master clock, 8-bit, no parity, 1 stop bit */
  TEST_ASSERT_EQUAL_UINT32(AT91C_US_USMODE_NORMAL |
                            AT91C_US_CLKS_CLOCK    |
                            AT91C_US_CHRL_8_BITS   |
                            AT91C_US_PAR_NONE      |
                            AT91C_US_NBSTOP_1_BIT,
                            UsartStandin.US_MR);
}

void testSetBaudRateWritesDivisorValueToBaudRateRegister(void)
{
  Usart_SetBaudRateRegister(26);
  TEST_ASSERT_EQUAL_UINT32(26, UsartStandin.US_BRGR);
}

void testEnableWritesTransmitterEnableBitToControlRegister(void)
{
  Usart_Enable();
  TEST_ASSERT_EQUAL_UINT32(AT91C_US_TXEN, UsartStandin.US_CR);
}

/* -------------------------------------------------------------------------
 * UsartTransmitBufferStatus
 * ------------------------------------------------------------------------- */

void testReadyToTransmitReturnsFalseWhenTxrdyBitIsClear(void)
{
  UsartStandin.US_CSR = 0x00;
  TEST_ASSERT_FALSE(Usart_ReadyToTransmit());
}

void testReadyToTransmitReturnsTrueWhenTxrdyBitIsSet(void)
{
  UsartStandin.US_CSR = AT91C_US_TXRDY;
  TEST_ASSERT_TRUE(Usart_ReadyToTransmit());
}

/* -------------------------------------------------------------------------
 * UsartPutChar
 * Note: Usart_PutChar spins on Usart_ReadyToTransmit() before writing.
 * Setting US_CSR = AT91C_US_TXRDY makes Usart_ReadyToTransmit() return
 * TRUE immediately so the spin-wait exits on the first check.
 * ------------------------------------------------------------------------- */

void testPutCharWritesByteToTransmitHoldingRegisterWhenReady(void)
{
  UsartStandin.US_CSR = AT91C_US_TXRDY;
  Usart_PutChar('Z');
  TEST_ASSERT_EQUAL_UINT32('Z', UsartStandin.US_THR);
}

void testPutCharWritesCorrectByteForDifferentCharacters(void)
{
  UsartStandin.US_CSR = AT91C_US_TXRDY;
  Usart_PutChar('\n');
  TEST_ASSERT_EQUAL_UINT32('\n', UsartStandin.US_THR);
}
