// #include <stdint.h>

#include "main.h"
#include "BlinkTask.h"
#include "Configure.h"    

//Most OS's frown upon direct memory access. 
//So we'll have to use fake registers during testing.
#ifdef TEST
  #define LOOP 
  #include "stub_io.h"
  #include "stub_interrupt.h"
#else
  #include <avr/interrupt.h>
  #include <avr/io.h>
  #define LOOP while(1)
  //The target will need a main. 
  //Our test runner will provide it's own and call AppMain()
  int main(void)              
  {
    return AppMain();
  }
#endif // TEST

int AppMain(void)
{
  Configure();

  LOOP
  {
    if(BlinkTaskReady==0x01)
    {
      BlinkTaskReady = 0x00;
      BlinkTask();
    }
  }
  return 0;
}

ISR(TIMER0_OVF_vect)
{
  /* toggle every thousand ticks */
  if (tick >= 1000)
  {
    /* signal our periodic task. */
    BlinkTaskReady = 0x01;
    /* reset the tick */
    tick = 0;
  }    
  tick++;
}
