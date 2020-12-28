#include "adc_hardware.h"
#include "adc_hardware_configurator.h"

void AdcHardware_Init(void)
{
  #ifdef SPECIFIC_CONFIG
  Adc_ResetSpec();
  #elif STANDARD_CONFIG
  Adc_Reset();
  #endif
}
