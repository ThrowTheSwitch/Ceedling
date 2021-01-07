#include "unity.h"
#include "adc_hardware.h"
#include "mock_adc_hardware_configurator.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_init_should_call_special_adc_reset(void)
{
  Adc_ResetSpec_Expect();

  // to check if also test file is compiled with this define
  #ifdef SPECIFIC_CONFIG
  AdcHardware_Init();
  #endif
}
