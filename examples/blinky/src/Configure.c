#include "Configure.h"
#include "main.h"
#ifdef TEST
  #include "stub_io.h"
  #include "stub_interrupt.h"
#else
  #include <avr/interrupt.h>
  #include <avr/io.h>
#endif // TEST

/* setup timer 0 to divide bus clock by 64.
   This results in a 1.024ms overflow interrupt
16000000/64
    250000

0.000 004s   *256
0.001024 
*/
void Configure(void)
{
  /* disable interrupts */
  cli();

  /* Configure TIMER0 to use the CLK/64 prescaler. */
  TCCR0B = _BV(CS00) | _BV(CS01);

  /* enable the TIMER0 overflow interrupt */
  TIMSK0 = _BV(TOIE0);

  /* confiure PB5 as an output. */
  DDRB |= _BV(DDB5);

  /* enable interrupts. */
  sei();
}

