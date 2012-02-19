#include "unity.h"
#include "main.h"
#include "stub_io.h"
#include "mock_Configure.h"
void setUp(void) {}    // every test file requires this function;
                       // setUp() is called by the generated runner before each test case function
void tearDown(void) {} // every test file requires this function;
                       // tearDown() is called by the generated runner before each test case function

void test_AppMain_should_call_configure(void) //Reqs: 
{
    /* Ensure known test state */
    blinkTaskReady=0;
    /* Setup expected call chain */
    Configure_Expect();
    /* Call function under test */
    AppMain();

    /* Verify test results */
    // TEST_ASSERT_EQUAL(0x20, PORTB);
}
void test_AppMain_should_call_configure_and_blinkTask(void) //Reqs: 
{
    /* Ensure known test state */
    blinkTaskReady=1;
    /* Setup expected call chain */
    Configure_Expect();
    
    /* Call function under test */
    AppMain();

    /* Verify test results */
    TEST_ASSERT_EQUAL(0, blinkTaskReady);
}