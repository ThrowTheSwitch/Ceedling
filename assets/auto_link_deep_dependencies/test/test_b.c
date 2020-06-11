#include "unity.h"
#include "b.h"
#include "mock_never_compiled.h"

void setUp(void) {}
void tearDown(void) {}

void test_function_from_b_should_return_8(void) {
  function_never_compiled_ExpectAndReturn(2, 2);
  TEST_ASSERT_EQUAL(8, function_from_b(2));
}
