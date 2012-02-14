#include "unity.h"
#include "main.h"
#include "mock_io.h"
void setUp(void) {}    // every test file requires this function;
                       // setUp() is called by the generated runner before each test case function
void tearDown(void) {} // every test file requires this function;
                       // tearDown() is called by the generated runner before each test case function

void test_AppMain_should_set_LED(void) //Reqs: 
{
    /* Ensure known test state */

    /* Setup expected call chain */

    /* Call function under test */
    AppMain();

    /* Verify test results */
    TEST_ASSERT_EQUAL(0x20, PORTB);
}