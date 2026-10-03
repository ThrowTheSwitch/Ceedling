#include "ceedling.h"
#include "unity.h"

// Two modules sharing the basename `config`. Each is named by its own directory, so
// each Partial must come from the module its directive names.
#include TEST_PARTIAL_PRIVATE_MODULE_AT(drivers/uart, config)
#include TEST_PARTIAL_PRIVATE_MODULE_AT(drivers/spi, config)

void setUp(void) {}
void tearDown(void) {}

// Each module defines functions the other does not. Reaching both from one test proves
// the two Partials came from different modules rather than collapsing onto one.
void test_each_module_contributes_its_own_private_function(void)
{
  TEST_ASSERT_EQUAL_INT(1, uart_only());
  TEST_ASSERT_EQUAL_INT(2, spi_only());
}

// Each module's private helper applies different arithmetic. Asserting both results
// proves each Partial carries its own module's code, not the other's.
void test_each_module_applies_its_own_arithmetic(void)
{
  TEST_ASSERT_EQUAL_INT(15, uart_adjust(5));
  TEST_ASSERT_EQUAL_INT(10, spi_adjust(5));
}
