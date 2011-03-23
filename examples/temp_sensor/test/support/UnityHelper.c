#include "unity.h"
#include "unity_internals.h"
#include "UnityHelper.h"

#if 0
void AssertEqualMyDataType(const MyDataType_T expected, const MyDataType_T actual, const unsigned short line)
{
  UNITY_TEST_ASSERT_EQUAL_INT(expected.length, actual.length, line, "MyDataType_T.length check failed");
  UNITY_TEST_ASSERT_EQUAL_MEMORY(expected.buffer, actual.buffer, expected.length, line, "MyDataType_T.buffer check failed");
}
#endif

