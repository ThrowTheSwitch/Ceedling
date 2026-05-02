# `:unity` Configure Unity's features

## `:defines`

Adds list of symbols used to configure Unity's features in its source and
header files at compile time.

See [Using Unity, CMock & CException](../../testing-guide/frameworks.md) for
much more on configuring and making use of these frameworks in your build.

To manage overall command line length, these symbols are only added to
compilation when a Unity C source file is compiled.

**_Note_**: No symbols must be set unless Unity's defaults are inappropriate
for your environment and needs.

**Default**: `[]` (empty)

## `:use_param_tests`

Configures Unity test runner generation and `#define`s for test compilation to
support Unity's parameterized test cases.

Example parameterized test case:

```c
TEST_RANGE([5, 100, 5])
void test_should_handle_divisible_by_5_for_parameterized_test_range(int num) {
  TEST_ASSERT_EQUAL(0, (num % 5));
}
```

See Unity documentation for more on parameterized test cases.

!!! warning "Parameterized Tests Incompatible with Preprocessing"
    Unity's parameterized tests are incompatible with Ceedling's preprocessing
    features enabled for test files. See more in
    [Ceedling's preprocessing documentation](../../testing-guide/conventions.md#preprocessing-gotchas).

**Default**: false
