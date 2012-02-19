// #include <stdint.h>

#include "main.h"
#include "blinkTask.h"
    
#ifdef TEST
  #define LOOP 
  #include "stub_io.h"
  #include "stub_interrupt.h"
#else
  #include <avr/interrupt.h>
  #include <avr/io.h>
  #define LOOP while(1)
int main(void)
{
  return AppMain();
}
#endif // TEST

// #define ConversionInProg()    ADCSRA && 0x40 
#define ToggleLED()           PORTB ^= _BV(PORTB5)      
#define SetLED()              PORTB |= 0x20
#define TOGGLE_LED()  PORTD ^= _BV(PORTD7)
// #define ClearLED()            PORTB &= ~0x20
// #define pinMode(x,y) ()
int AppMain(void)
{
  int i;

  Configure();

  LOOP
  {
    if(blinkTaskReady==0x01)
    {
      // cli();
      blinkTaskReady = 0x00;
      // sei();
// SetLED()  ;

      // blinkTask();
    }
    // Check for conversion complete
    
    // if( ConversionInProg() == 0x00 )
    // {
      // int currentValue = ADCH;
      // currentValue <<= 2;
    // PORTB ^= _BV(PORTB5);
// PORTD = _BV(PORTD7);
// PORTD = 0x80;
      // if(currentValue > 0x01FF)
// TOGGLE_LED();
      // else 
      //  ClearLED();
// for(i=0;i<0xff;i++);
    /* toggle the LED */
    // PORTB ^= _BV(PORTB5);
// SetLED();
      // Start another conversion
      // StartConversion();
    // }
  }
  return 0;
}

// void StartConversion()
// {
//   ADCSRA |= 0x40;
  
// }


ISR(TIMER0_OVF_vect)
{
  static uint16_t tick = 0;
  // static char tick = 0;

  /* preload the timer. */
  TCNT0 = TIMER_RESET_VAL;
  /* toggle every thousand ticks */
  if (tick >= 500)
  {
  PORTB ^= _BV(PORTB5);
    /* signal our periodic task. */
    blinkTaskReady = 0x01;
    /* reset the tick */
    tick = 0;
  }    
  tick++;
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
