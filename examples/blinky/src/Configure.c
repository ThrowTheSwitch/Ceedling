#include "Configure.h"
#include "main.h"
#ifdef TEST
  #define LOOP 
  #include "stub_io.h"
  #include "stub_interrupt.h"
#else
  #include <avr/interrupt.h>
  #include <avr/io.h>
  #define LOOP while(1)
#endif // TEST

void Configure(void)
{
  /* disable interrupts */
  cli();

  /* Configure TIMER0 to use the CLK/64 prescaler. */
  TCCR0B = _BV(CS00) | _BV(CS01);

  /* enable the TIMER0 overflow interrupt */
  TIMSK0 = _BV(TOIE0);

  /* set the initial timer counter value. */
  TCNT0 = TIMER_RESET_VAL;

  /* confiure PB5 as an output. */
  DDRB |= _BV(DDB5);

  /* turn off surface mount LED */
  PORTB &= ~_BV(PORTB5);

  /* enable interrupts. */
  sei();
}

