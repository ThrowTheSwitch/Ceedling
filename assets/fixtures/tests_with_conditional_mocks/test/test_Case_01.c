#include "unity.h"
#include "Case_01.h"

// Issue #1083: each hardware variant's header exists only in a separate module test
// environment, so in this project only the final branch can build
#if defined (UNITTEST_HW_DEPENDANT_MOCK_NEEDED)
  #if (TARGET_BOARD_HARDWARE == HW_TYPE_1)
    #include "mock_Gpt_HwType1.h"
  #else
    #include "mock_Gpt_HwType2.h"
  #endif
#else
  #include "mock_Gpt.h"
#endif

void test_timer_starts_the_hardware_timer(void)
{
  Gpt_StartTimer_Expect();

  OS_Timer_CPU0();
}
