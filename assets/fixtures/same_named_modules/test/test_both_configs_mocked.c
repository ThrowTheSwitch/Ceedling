#include "ceedling.h"
#include "unity.h"

// Two modules sharing the basename `config`, each mocked as a Partial by directory.
#include MOCK_PARTIAL_PUBLIC_MODULE_AT(drivers/uart, config)
#include MOCK_PARTIAL_PUBLIC_MODULE_AT(drivers/spi, config)

void setUp(void) {}
void tearDown(void) {}

// Each module's own public function is mocked separately, so an expectation set on one
// cannot be satisfied by the other.
void test_each_module_is_mocked_separately(void)
{
  uart_config_baud_ExpectAndReturn(7);
  spi_config_clock_div_ExpectAndReturn(9);

  TEST_ASSERT_EQUAL_INT(7, uart_config_baud());
  TEST_ASSERT_EQUAL_INT(9, spi_config_clock_div());
}
