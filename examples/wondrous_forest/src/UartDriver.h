/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef UART_DRIVER_H
#define UART_DRIVER_H

#include "Types.h"

void UartDriver_Init(uint32 baud_rate);
void UartDriver_SendByte(uint8 byte);
void UartDriver_SendString(const char* str);
bool UartDriver_IsTxReady(void);

#endif /* UART_DRIVER_H */
