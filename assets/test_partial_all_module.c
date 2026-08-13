#include "unity.h"
#include "ceedling.h"

#include MOCK_PARTIAL_ALL_MODULE(partial_all_module)

void setUp(void) {}
void tearDown(void) {}

void test_all_module_should_mock_both_a_plain_prototype_and_a_static_inline_function(void)
{
  PartialAllModule_Init_Expect(3);
  PartialAllModule_Init(3);

  PartialAllModule_DoubleValue_ExpectAndReturn(3, 6);
  TEST_ASSERT_EQUAL_INT(6, PartialAllModule_DoubleValue(3));
}
