#ifndef MY_MODULE_CONFIG_H
#define MY_MODULE_CONFIG_H

#define MODULE_1_ENABLED
//#define MODULE_2_ENABLED

int Module0_FunctionToCall(void);

#ifdef MODULE_1_ENABLED
#include "MyModulePart1.h"
#endif

#ifdef MODULE_2_ENABLED
#include "MyModulePart2.h"
#endif

#endif
