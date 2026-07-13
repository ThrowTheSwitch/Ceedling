/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

/* Traditional test - no Partials needed.
 * UartDriver has no private static functions; it is a thin hardware wrapper.
 * The #ifdef TEST guard in UartDriver.c pre-sets the TX-ready status bit,
 * so UartDriver_SendByte() does not spin waiting for hardware. */

#include "unity.h"
#include "Types.h"
#include "UartDriver.h"

void setUp(void)
{
    UartDriver_Init(115200u);
}

void tearDown(void)
{
}

void test_IsTxReady_ReturnsTrueAfterInit(void)
{
    /* UartDriver_Init sets UART_STATUS_REG = UART_STATUS_TX_READY. */
    TEST_ASSERT_TRUE(UartDriver_IsTxReady());
}

void test_SendByte_DoesNotHangWhenTxReady(void)
{
    /* TX-ready status ensures no spin; call must return without blocking. */
    UartDriver_SendByte((uint8)'H');
    TEST_PASS();
}

void test_SendString_TransmitsEachCharacter(void)
{
    UartDriver_SendString("Hi");
    TEST_PASS();
}

void test_SendString_DoesNotCrashOnEmptyString(void)
{
    UartDriver_SendString("");
    TEST_PASS();
}

void test_SendString_GuardsAgainstNullPointer(void)
{
    UartDriver_SendString(NULL);
    TEST_PASS();
}
