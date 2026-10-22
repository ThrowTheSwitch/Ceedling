#include "unity.h"
#include "Case_01.h"

// A branch that is off names its mock with letter case its header doesn't have
#ifdef LEGACY_NAMES
#include "mock_gpt.h"
#else
#include "mock_Gpt.h"
#endif

void test_timer_starts_the_hardware_timer(void)
{
  Gpt_StartTimer_Expect();

  OS_Timer_CPU0();
}
