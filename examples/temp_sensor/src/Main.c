/* =========================================================================
    Ceedling - Test-Centered Build System for C
    ThrowTheSwitch.org
    Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
    SPDX-License-Identifier: MIT
========================================================================= */

#include "Types.h"

#include "IntrinsicsWrapper.h"
#include "Executor.h"

#include "Model.h"
#include "TaskScheduler.h"
#include "calculators/TemperatureCalculator.h"
#include "TemperatureFilter.h"

#include "UsartConductor.h"
#include "UsartHardware.h"
#include "UsartConfigurator.h"
#include "UsartPutChar.h"
#include "UsartModel.h"
#include "calculators/UsartBaudRateRegisterCalculator.h"
#include "UsartTransmitBufferStatus.h"

#include "TimerConductor.h"
#include "TimerHardware.h"
#include "TimerConfigurator.h"
#include "TimerInterruptConfigurator.h"
#include "TimerInterruptHandler.h"
#include "TimerModel.h"

#include "AdcConductor.h"
#include "AdcHardware.h"
#include "AdcHardwareConfigurator.h"
#include "AdcTemperatureSensor.h"
#include "AdcModel.h"

int AppMain(void)
{
  Executor_Init();

  while(Executor_Run());
  
  return 0;
}

#ifndef TEST
int main(void)
{
  return AppMain();
}
#endif // TEST
