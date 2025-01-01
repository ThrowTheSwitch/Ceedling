/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#ifndef _ADCTEMPERATURESENSOR_H
#define _ADCTEMPERATURESENSOR_H

#include "Types.h"

void Adc_StartTemperatureSensorConversion(void);
bool Adc_TemperatureSensorSampleReady(void);
uint16 Adc_ReadTemperatureSensor(void);

#endif // _ADCTEMPERATURESENSOR_H
