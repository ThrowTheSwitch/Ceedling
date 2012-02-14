// #include <avr/interrupt.h>
// #include <stdint.h>

#include "main.h"

    
// #define ConversionInProg()    ADCSRA && 0x40 
#define ToggleLED()           PORTB ^= _BV(PORTB5)      
#define SetLED()              PORTB |= 0x20
// #define ClearLED()            PORTB &= ~0x20

#ifdef TEST
  #define LOOP 
  #include "mock_io.h"
#else
  #include <avr/io.h>
  #define LOOP while(1)
int main(void)
{
  return AppMain();
}
#endif // TEST


int AppMain(void)
{
  configure();

  // unsigned int maxValue = 0;
  // unsigned int lastValue = 0;


  LOOP
  {
    // Check for conversion complete
    
    // if( ConversionInProg() == 0x00 )
    // {
      // int currentValue = ADCH;
      // currentValue <<= 2;
    // PORTB ^= _BV(PORTB5);

      // if(currentValue > 0x01FF)
        SetLED();
      // else 
      //  ClearLED();

      // Start another conversion
      // StartConversion();
    // }
      
  }
while(1){}
  return 0;
}

// void StartConversion()
// {
//   ADCSRA |= 0x40;
  
// }

void configure(void)
{
  /* disable interrupts */
  // cli();

  /* configure TIMER0 to use the CLK/64 prescaler. */
  TCCR0B = _BV(CS00) | _BV(CS01);

  /* enable the TIMER0 overflow interrupt */
  TIMSK0 = _BV(TOIE0);

  /* set the initial timer counter value. */
  TCNT0 = TIMER_RESET_VAL;

  /* confiure PB5 as an output. */
  DDRB |= _BV(DDB5);

  /* turn off surface mount LED on */
  PORTB &= ~_BV(PORTB5);

  // setupADC();

  /* enable interrupts. */
  // sei();
}

// void setupADC()
// {

//     // Set the port to analog (Disable digital)
//     DIDR0 |= 0x01;

//     // Disable power reduction feature
//     PRR &= ~0x01;

//     // Configure the ADC to use AVcc as the reference voltage (5VDC)
//     ADMUX |= 0x40;

//     // Enable auto triggering of A/D conversions
//     //ADCSRA _SFR_MEM8 |= 0x20;

//     // Set ADC to Left Adjust
//     ADMUX |= 0x40;

//     // Enable the ADC
//     ADCSRA |= 0x80;

//     // Start a conversion
//     StartConversion();
// }

// void task(void)
// {
//   static uint16_t tick = 0;

//   /* toggle every thousand ticks */
//   if (tick >= 500)
//   {
//     /* toggle the LED */
//     PORTB ^= _BV(PORTB5);

//     /* reset the tick */
//     tick = 0;
//   }

//   tick++;
// }

// ISR(TIMER0_OVF_vect)
// {
//   /* preload the timer. */
//   TCNT0 = TIMER_RESET_VAL;
  
//   /* call our periodic task. */
//   task();
// }

