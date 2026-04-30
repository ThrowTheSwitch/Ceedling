# Accessing Static Variables

## File-Scoped Static Variables

A file-scoped `static` variable is declared at the top level of a `.c` file
with the `static` keyword. Like a `static` function, it has _internal linkage_ 
-- the linker cannot see it outside the translation unit in which it is defined.
This means test code in a separate translation unit cannot read or write it,
making it impossible to inspect state or reset it between test cases without
modifying the production source.

When Ceedling generates a Partial it automatically copies every file-scoped 
`static` variable found in the source module into the Partial and strips the 
`static` keyword. The resulting definition in the generated `_impl.c` file 
has external linkage. A matching `extern` declaration is emitted in the 
generated `_impl.h` header. Including any `TEST_PARTIAL_*_MODULE` macro brings 
that `extern` declaration into scope, causing the variable to accessible in 
test code directly by its **original name** — no renaming or helper macro is 
required.

### Partial file-scoped static variable example

Extending the sensor module with a file-scoped error counter:

```c
// sensor.c -----------------------------------------------
static uint32_t g_error_count = 0; // File-scoped; invisible outside sensor.c

int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    if (raw == 0xFFFF) { // sentinel value signals hardware error
        g_error_count++;
        return -1;
    }
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling strips `static` when generating the test Partial:

```c
// ceedling_partial_sensor_impl.c (generated) ---------------
uint32_t g_error_count = 0; // `static` stripped -- now has external linkage
// ...
int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    if (raw == 0xFFFF) {
        g_error_count++;
        return -1;
    }
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

```c
// ceedling_partial_sensor_impl.h (generated) ---------------
extern uint32_t g_error_count; // `extern` declaration -- immediately available in test code
// ...
```

Because `#include TEST_PARTIAL_*_MODULE()` automatically causes the generated
Partial header file to be included in your test, the `extern`ed variable is
immediately available to you in your test.

In the test file, the variable is accessed directly by its original name:

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"
#include "mock_hal.h"

// Brings `extern g_error_count` into scope
#include TEST_PARTIAL_ALL_MODULE(sensor)

void setUp(void) {
    g_error_count = 0; // Reset to known state before each test
}

void test_ReadCelsius_counts_hardware_errors(void)
{
    HAL_SensorRead_ExpectAndReturn(0xFFFF); // Simulate hardware error
    TEST_ASSERT_EQUAL_INT(-1, Sensor_ReadCelsius());
    // Access the previously inaccessible `g_error_count`
    TEST_ASSERT_EQUAL_UINT32(1, g_error_count);
}
```

## Function-scoped static variables

C allows variables to be declared `static` inside a function body. Unlike a
local variable, a function-scoped `static` variable persists across calls —
its storage is allocated once and retains its value for the lifetime of the
program. This persistence makes these variables useful for call counters, 
cached state, accumulated error totals, etc.

In ordinary C, a function-scoped `static` variable is completely inaccessible
outside its containing function; the C standard does not provide any way to
take its address or read its value from another translation unit. This makes
it impossible to inspect or reset it from a test.

When Ceedling generates a Partial, it automatically promotes all function-scoped
`static` variables to module scope in the generated implementation files.
The original declaration inside the function body is replaced with a no-op
statement so that source line mappings for coverage reporting remain accurate.

### Renaming to prevent collisions

Multiple functions in the same module may each contain a function-scoped
`static` variable with the same name — for example, both `Foo_Init()` and
`Foo_Reset()` might each have `static uint32_t call_count = 0;`. Promoting
both to module scope without renaming would produce a duplicate symbol error
at compilation.

Ceedling resolves this by prepending a prefix of `partial_` and the containing
function's name to each promoted variable's name:

```
partial_<function_name>_<variable_name>
```

Example renaming:

| Original declaration (inside function) | Containing function | Promoted name |
|---|---|---|
| `static uint32_t call_count = 0;` | `Sensor_ReadCelsius` | `partial_Sensor_ReadCelsius_call_count` |
| `static bool initialized = false;` | `Sensor_Init` | `partial_Sensor_Init_initialized` |
| `static int error_count;` | `Sensor_Init` | `partial_Sensor_Init_error_count` |

The promoted variable is defined in the generated implementation source
(`ceedling_partial_<module>_impl.c`) and declared `extern` in the generated
implementation header (`ceedling_partial_<module>_impl.h`). Including the
implementation header via a `TEST_PARTIAL_*_MODULE` macro therefore makes all
promoted variables available to your test code.

### `PARTIAL_LOCAL_VAR()` macro to access promoted function-scoped static variables

Typing `partial_Sensor_ReadCelsius_call_count` throughout a test file is
error-prone. The `PARTIAL_LOCAL_VAR` macro, defined in `ceedling.h`, assembles
the promoted name from its two components:

```c
PARTIAL_LOCAL_VAR(function_name, variable_name)
// expands to: partial_<function_name>_<variable_name>
```

`PARTIAL_LOCAL_VAR()` is not a function call. The macro expands to a simple 
C identifier. It can appear anywhere a variable name is legal — in expressions, 
assertions, and assignments.

### Example use of `PARTIAL_LOCAL_VAR()`

Extending the sensor module from earlier examples:

```c
// sensor.c -----------------------------------------------
int Sensor_ReadCelsius(void)
{
    // Function-scoped static variable that tracks total calls
    static uint32_t sample_count = 0;
    sample_count++;

    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling promotes `sample_count` to `partial_Sensor_ReadCelsius_sample_count`.

In the copy of `Sensor_ReadCelsius()` organized in a generated Partial, 
Ceedling replaces the variable declaration inside the function with a no-op
to preserve code coverage line tracking.

```c
// ceedling_partial_sensor_impl.c (generated) ---------------
// ...
int Sensor_ReadCelsius(void)
{
    (void)0; /* static uint32_t sample_count = 0 */
    partial_Sensor_ReadCelsius_sample_count++;

    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

Ceedling simultaneously organizes an `extern` statement in the generated 
Partial header file.

```c
// ceedling_partial_sensor_impl.h (generated) ---------------
// ...
extern uint32_t partial_Sensor_ReadCelsius_sample_count;
// ...
```

Because `#include TEST_PARTIAL_*_MODULE()` automatically causes the generated
Partial header file to be included in your test, the promoted, renamed, and
`extern`ed variable is immediately available to you in your test.

In your test file, `PARTIAL_LOCAL_VAR()` makes the variable accessible for both
reset and assertion:

```c
// test_sensor_partial.c -----------------------------------
#include "unity.h"
#include "ceedling.h"
#include TEST_PARTIAL_PRIVATE_MODULE(sensor)

void setUp(void)
{
    // Reset promoted static back to its initial value before each test
    PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count) = 0;
}

void test_ReadCelsius_increments_sample_count_on_each_call(void)
{
    HAL_SensorRead_ExpectAndReturn(1000);
    Sensor_ReadCelsius();
    TEST_ASSERT_EQUAL_UINT32(1, PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count));

    HAL_SensorRead_ExpectAndReturn(2000);
    Sensor_ReadCelsius();
    TEST_ASSERT_EQUAL_UINT32(2, PARTIAL_LOCAL_VAR(Sensor_ReadCelsius, sample_count));
}
```

### What `PARTIAL_LOCAL_VAR()` cannot do

`PARTIAL_LOCAL_VAR` is a token-pasting macro — it constructs a C identifier at
compile time. It cannot be used with a runtime string or a variable holding a
function name. Both arguments must be literal tokens that match the original
C identifiers exactly (the function name and the variable name as they appear
in the source file).
