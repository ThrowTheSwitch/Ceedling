#include "ceedling.h"
#include "unity.h"

// Only the uart module is Partialized. The spi module is exercised through its own
// public function, so coverage must report each module separately.
#include "drivers/spi/config.h"
#include TEST_PARTIAL_PRIVATE_MODULE_AT(drivers/uart, config)

void setUp(void) {}
void tearDown(void) {}

void test_uart_private_function_through_its_partial(void)
{
  TEST_ASSERT_EQUAL_INT(15, uart_adjust(5));
}

void test_spi_public_function_through_its_own_source(void)
{
  TEST_ASSERT_EQUAL_INT(18, spi_config_clock_div());
}
