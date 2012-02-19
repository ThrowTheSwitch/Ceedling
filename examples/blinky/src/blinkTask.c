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
