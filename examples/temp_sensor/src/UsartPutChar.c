/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "UsartPutChar.h"
#include "UsartTransmitBufferStatus.h"
#ifdef SIMULATE
#include <stdio.h>
#endif

void Usart_PutChar(char data)
{
  while(!Usart_ReadyToTransmit());
#ifdef SIMULATE
  printf("%c", data);
#else
  AT91C_BASE_US0->US_THR = data;
#endif
}
