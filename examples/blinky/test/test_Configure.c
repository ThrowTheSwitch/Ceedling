#include "unity.h"
#include "Configure.h"
#include "stub_io.h"
#include "mock_stub_interrupt.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_Configure_should_setup_timer_and_port(void)
    {
    /* Ensure known test state */

    /* Setup expected call chain */
    //these are defined into assembly instructions. 
    cli_Expect(); 
    sei_Expect();
    /* Call function under test */
    Configure();

    /* Verify test results */
    TEST_ASSERT_EQUAL(3, TCCR0B);
    TEST_ASSERT_EQUAL(1, TIMSK0);
    TEST_ASSERT_EQUAL(0x20, DDRB);
}
