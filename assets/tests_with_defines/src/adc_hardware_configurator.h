#ifndef _ADCHARDWARECONFIGURATOR_H
#define _ADCHARDWARECONFIGURATOR_H

#ifdef SPECIFIC_CONFIG
void Adc_ResetSpec(void);
#elif defined(STANDARD_CONFIG)
void Adc_Reset(void);
#endif

#endif // _ADCHARDWARECONFIGURATOR_H
