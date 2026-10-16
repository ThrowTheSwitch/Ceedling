#include "unity.h"
#include "mock_MyModuleConfig.h"

// Issue #1083: MyModuleConfig.h, reached only through its mock, decides which module
// mocks this test needs
#ifdef MODULE_1_ENABLED
#include "mock_MyModulePart1.h"
#endif

#ifdef MODULE_2_ENABLED
#include "mock_MyModulePart2.h"
#endif

#include "Case_02.h"

void test_function_sums_the_enabled_modules(void)
{
  int expected = 1;

  Module0_FunctionToCall_ExpectAndReturn( 1 );
#ifdef MODULE_1_ENABLED
  Module1_FunctionToCall_ExpectAndReturn( 2 );
  expected += 2;
#endif
#ifdef MODULE_2_ENABLED
  Module2_FunctionToCall_ExpectAndReturn( 4 );
  expected += 4;
#endif

  TEST_ASSERT_EQUAL( expected, FunctionToTest( 0 ) );
}
