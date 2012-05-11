#include "unity.h"
#include "BlinkTask.h"
#include "stub_io.h"

// every test file requires this function
// setUp() is called by the generated runner before each test case function
void setUp(void)
{
    PORTB = 0;
}    
                       
// every test file requires this function
// tearDown() is called by the generated runner before each test case function
void tearDown(void)
{
}

void test_BlinkTask_should_toggle_led(void)
{
    /* Ensure known test state */

    /* Setup expected call chain */

    /* Call function under test */
    BlinkTask();

    /* Verify test results */
    TEST_ASSERT_EQUAL(0x20, PORTB);
}
void test_BlinkTask_should_toggle_led_LOW(void)
{
    /* Ensure known test state */
    PORTB = 0x20;

    /* Setup expected call chain */

    /* Call function under test */
    BlinkTask();

    /* Verify test results */
    TEST_ASSERT_EQUAL(0, PORTB);
}
