#include "unity.h"
#include "Configure.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_Configure_should_setup_timer_and_port(void) //Reqs: 
{
    /* Ensure known test state */

    /* Setup expected call chain */
    cli_Expect();
    sei_Expect();
    /* Call function under test */
    Configure();

    /* Verify test results */
    TEST_ASSERT_EQUAL(3, actual);
}
