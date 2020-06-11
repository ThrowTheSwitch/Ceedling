#include "unity.h"
#include "a.h"
#include "mock_never_compiled.h"

void setUp(void) {}
void tearDown(void) {}

void test_function_from_a_should_return_16(void) {
  function_never_compiled_ExpectAndReturn(2, 2);
  TEST_ASSERT_EQUAL(16, function_from_a(2));
}
