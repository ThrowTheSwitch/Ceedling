/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

// #include <stdint.h>

#include "BlinkTask.h"

#ifdef TEST
  #define LOOP 
  #include "stub_io.h"
#else
  #include <avr/interrupt.h>
  #include <avr/io.h>
  #define LOOP while(1)
#endif // TEST



void BlinkTask(void)
{
  /* toggle the LED */
  PORTB ^= _BV(PORTB5);

}
