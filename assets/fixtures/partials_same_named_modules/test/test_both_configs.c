#include "ceedling.h"
#include "unity.h"

// Two modules sharing the basename `config`. Each is named by its own directory, so
// each Partial must come from the module its directive names.
#include TEST_PARTIAL_PRIVATE_MODULE_AT(drivers/uart, config)
#include TEST_PARTIAL_PRIVATE_MODULE_AT(drivers/spi, config)

void setUp(void) {}
void tearDown(void) {}

// Each module defines one function the other does not. Reaching both from one test
// proves the two Partials came from different modules rather than collapsing onto one.
void test_each_module_only_function_is_reachable(void)
{
  TEST_ASSERT_EQUAL_INT(1, uart_only());
  TEST_ASSERT_EQUAL_INT(2, spi_only());
}

// Both modules compute through their own private `adjust`, defined with different
// arithmetic. Asserting both public results proves each Partial carries its own
// module's arithmetic, not the other's.
void test_each_module_applies_its_own_arithmetic(void)
{
  TEST_ASSERT_EQUAL_INT(1163, uart_config_baud());
  TEST_ASSERT_EQUAL_INT(18, spi_config_clock_div());
}
