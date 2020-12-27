#include "adc_hardware_configurator.h"

#ifdef SPECIFIC_CONFIG
void Adc_ResetSpec(void)
{
}
#elif STANDARD_CONFIG
void Adc_Reset(void)
{
}
#endif
