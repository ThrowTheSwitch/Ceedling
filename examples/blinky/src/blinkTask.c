// #include <stdint.h>

#include "BlinkTask.h"

    
// #define ConversionInProg()    ADCSRA && 0x40 
#define ToggleLED()           PORTB ^= _BV(PORTB5)      
#define SetLED()              PORTB |= 0x20
#define TOGGLE_LED()  PORTD ^= _BV(PORTD7)
// #define ClearLED()            PORTB &= ~0x20
// #define pinMode(x,y) ()
#ifdef TEST
  #define LOOP 
  #include "mock_io.h"
  #include "mock_interrupt.h"
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
