// `helloPrivate` is `static` through PRIVATE in private_macro.h. Its declaration for the
// test file comes from the generated Partial's own header via TEST_PARTIAL_ALL_MODULE.
#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_ALL_MODULE(private_macro)
#include "private_macro.h"

void test_helloPrivate(void) {
  TEST_ASSERT_EQUAL_INT( 42, helloPrivate( 41 ) );
}
