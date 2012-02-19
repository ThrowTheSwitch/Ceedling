#ifndef __MAIN_H__
#define __MAIN_H__

/* Assuming a clock rate of 16Mhz and a CLK/64 prescaler,
 * we will see 250 ticks per millisecond. If we want to
 * have the timer overflow every millisecond, we need to
 * initialize the counter to 5 after each tick. */
#define TIMER_RESET_VAL 5

void setupADC();
void StartConversion();
void task(void);
int main(void);
int AppMain(void);
int blinkTaskReady;

#endif /* __MAIN_H__ */
