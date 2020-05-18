#include "unity.h"
#include "c.h"
#include "mock_never_compiled.h"

void setUp(void) {}
void tearDown(void) {}

void test_function_from_c_should_return_4(void) {
  function_never_compiled_ExpectAndReturn(2, 2);
  TEST_ASSERT_EQUAL(4, function_from_c(2));
}
