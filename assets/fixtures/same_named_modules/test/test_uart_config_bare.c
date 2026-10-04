#include "ceedling.h"
#include "unity.h"

#include TEST_PARTIAL_PRIVATE_MODULE(config)

void setUp(void) {}
void tearDown(void) {}

// Each config module's private helper applies different arithmetic. Asserting the
// result proves which module the Partial came from.
void test_adjust_applies_the_uart_offset(void)
{
  TEST_ASSERT_EQUAL_INT(15, uart_adjust(5));
}

void test_uart_only_is_reachable(void)
{
  TEST_ASSERT_EQUAL_INT(1, uart_only());
}
