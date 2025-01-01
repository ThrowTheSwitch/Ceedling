/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"
#include "UsartHardware.h"
#include "UsartConfigurator.h"
#include "UsartPutChar.h"

void UsartHardware_Init(uint8 baudRateRegisterSetting)
{
  Usart_ConfigureUsartIO();
  Usart_EnablePeripheralClock();
  Usart_Reset();
  Usart_ConfigureMode();
  Usart_SetBaudRateRegister(baudRateRegisterSetting);
  Usart_Enable();
}

void UsartHardware_TransmitString(char* data)
{
  while(*data != NULL)
  {
    Usart_PutChar(*data++);
  }
}
