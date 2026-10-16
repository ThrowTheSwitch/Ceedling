#include "MyModuleConfig.h"
#include "Case_02.h"

int FunctionToTest(int Param)
{
  int Result = Module0_FunctionToCall();

#ifdef MODULE_1_ENABLED
  Result += Module1_FunctionToCall();
#endif
#ifdef MODULE_2_ENABLED
  Result += Module2_FunctionToCall();
#endif

  return Result;
}
