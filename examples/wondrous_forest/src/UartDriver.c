/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "UartDriver.h"

/* In test builds, substitute static variables for hardware register addresses.
 * TX-ready status is pre-set so UartDriver_SendByte() does not spin. */
#ifdef TEST
#define UART_STATUS_TX_READY (1u << 7)
static uint32 s_uart_status = (1u << 7);
static uint8  s_uart_data   = 0u;
static uint32 s_uart_baud   = 0u;

#define UART_STATUS_REG  s_uart_status
#define UART_DATA_REG    s_uart_data
#define UART_BAUD_REG    s_uart_baud
#else
#define UART_BASE_ADDR       (0x40011000UL)
#define UART_STATUS_REG      (*((volatile uint32*)(UART_BASE_ADDR + 0x00u)))
#define UART_DATA_REG        (*((volatile uint8*) (UART_BASE_ADDR + 0x04u)))
#define UART_BAUD_REG        (*((volatile uint32*)(UART_BASE_ADDR + 0x08u)))
#define UART_STATUS_TX_READY (1u << 7)
#endif

void UartDriver_Init(uint32 baud_rate)
{
    UART_BAUD_REG   = baud_rate;
    UART_STATUS_REG = UART_STATUS_TX_READY;
}

bool UartDriver_IsTxReady(void)
{
    return (UART_STATUS_REG & UART_STATUS_TX_READY) != 0u;
}

void UartDriver_SendByte(uint8 byte)
{
    while (!UartDriver_IsTxReady()) { /* spin */ }
    UART_DATA_REG = byte;
}

void UartDriver_SendString(const char* str)
{
    if (str == NULL) { return; }
    while (*str != '\0')
    {
        UartDriver_SendByte((uint8)*str);
        str++;
    }
}
