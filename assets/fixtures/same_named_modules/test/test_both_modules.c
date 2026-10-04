#include "unity.h"

// Two headers sharing the basename `config`, each named by its own path. Ceedling's
// own convention correlates each with the source beside it, so both modules compile
// and link into this one test.
#include "drivers/uart/config.h"
#include "drivers/spi/config.h"

void setUp(void) {}
void tearDown(void) {}

// Each module computes through its own private `adjust`, defined with different
// arithmetic. Asserting both results proves each public function ran against its own
// module's code rather than the other's.
void test_each_module_computes_its_own_result(void)
{
  TEST_ASSERT_EQUAL_INT(1163, uart_config_baud());
  TEST_ASSERT_EQUAL_INT(18, spi_config_clock_div());
}
