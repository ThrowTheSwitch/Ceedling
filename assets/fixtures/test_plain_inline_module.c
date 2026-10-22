#include "unity.h"
#include "mock_plain_inline_module.h"

void setUp(void) {}
void tearDown(void) {}

void test_plain_inline_module_mocks_a_static_inline_function_via_treat_inlines(void)
{
  // The mocked return value (42) deliberately differs from what the real
  // implementation would compute (3 * 3 = 9) -- if the mock is bypassed and
  // the real body runs instead, this assertion fails unambiguously rather
  // than coincidentally matching.
  PlainInlineModule_TripleValue_ExpectAndReturn(3, 42);
  TEST_ASSERT_EQUAL_INT(42, PlainInlineModule_TripleValue(3));
}
