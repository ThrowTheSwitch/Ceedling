# What Is a Partial?

## Slicing and dicing your C code

Ceedling reads your real source and header files, extracts their C contents,
and generates new C files that comprise a Partial.

Ceedling can create two kinds of Partials:

1. A **_Test Partial_** for exposing otherwise inaccessible functions and 
   variables to your test case assertions.
1. A **_Mock Partial_** for mocking otherwise inaccessible functions in your
   source code.

When a test file references a Partial, Ceedling excludes the original source
file from that test executable's build. The generated Partial 
source is compiled and linked in place of the original source C.

!!! note "Purpose-specific C language handling"
    Ceedling includes its own custom, purpose-specific lexing for recognizing
    C language elements. This was the best way to handle all cases across
    platforms. This custom lexer even handles many compiler extensions 
    (e.g. Microsoft’s `__declspec` and GCC's `__attribute__()`).
    
    On the upside, this approach provides everything Partials need. On the 
    downside, until exercised by a great deal of real world code, this custom 
    C handling will likely have failings and gaps.

### Partials creation step-by-step

When creating a Partial, Ceedling:

1. Runs your source code under test through the preprocessor to:
    1. Handle `#ifdef` blocks and strip comments.
    1. Collect the `#include` directives.
    1. Expand decorator macros (e.g. `STATICINLINE`) in function signatures.
1. Lexes the code under test to collect its individual C language elements
   (e.g. `typedef`s, macros, functions, variables, etc.).
1. Generates a new set of C files in a _partials/_ build directory. The 
   contents of these new files are:
    1. Reconstructed with the `#include` directives from (1) and elements 
       from (2).
    1. Reorganized and slightly altered so the C elements can be accessed by 
       assertions and mocks in your test cases. Functions are stripped of 
       `static` and `inline`. Variables are stripped of `static` and `extern`ed.
1. Structures the test build to omit the original source file from the 
   resulting test executable. Generated Partials are self-sufficient stand-ins 
   for the original C code from which the Partials are derived.
1. Maps the reorganized functions in generated Partials back to the 
   original source module's filepath and line numbers (using GCC's `#line` 
   directive) for correct test coverage reporting.

### Generated files

| Partial | Purpose | Generated filename pattern |
|---|---|---|
| Testable header | <ul><li>Declares functions</li><li>`extern`s variables</li></ul> | `ceedling_partial_<module>_impl.h` |
| Testable source | <ul><li>Defines functions</li><li>Defines `static`-less variables</li></ul> | `ceedling_partial_<module>_impl.c` |
| Mockable header | <ul><li>Declares function signatures</li></ul> | `ceedling_partial_<module>_interface.h` |

Ceedling uses CMock to generate mocks from Partials interface header files
just as it does for any other mockable header files.

!!! danger "Do not directly access generated Partials files"
    You as the test author will never directly interact with generated 
    Partials C files. Do not modify these generated files or 
    incorporate them into your tests except with the accompanying macros.

## Partials walk-through example

### Temperature sensor module

Imagine a temperature sensor code module…

```c
// sensor.h -----------------------------------------------
void Sensor_Init(void);
int  Sensor_ReadCelsius(void);
```

```c
// sensor.c -----------------------------------------------
#include "sensor.h"
#include "hal.h" // Hardware Abstraction Layer (to be mocked)

// Private helper -- static, not visible outside this translation unit
static int _ConvertRawToMilliCelsius(uint16_t raw)
{
    return (int)raw * 10 - 40000;
}

void Sensor_Init(void)
{
    HAL_SensorEnable();
}

int Sensor_ReadCelsius(void)
{
    uint16_t raw = HAL_SensorRead();
    return _ConvertRawToMilliCelsius(raw) / 1000;
}
```

### Testing & mocking a `static` helper

You as a test author want to test and mock the `static` helper `_ConvertRawToMilliCelsius()`.

1. **Test** `_ConvertRawToMilliCelsius()` directly
2. **Mock** `_ConvertRawToMilliCelsius()` while testing `Sensor_ReadCelsius()`

Partials allows you to accomplish both of these goals with no changes to
_sensor.c_ even though `_ConvertRawToMilliCelsius()` is static.

!!! warning "A Function Cannot Be Both Tested and Mocked"
    A core restriction of the C language remains here! `_ConvertRawToMilliCelsius()`
    cannot be both tested and mocked in the same test. Attempting to do so would
    duplicate the function and cause a doubly-defined symbol failure during linking.
    We solve this by simply creating two peer test files for the different Partials
    usage scenarios.

### Using the testable partial

```c
// test_sensor_partials_test.c -----------------------------------
#include "unity.h"
#include "ceedling.h" // Required -- defines Partial directive macros
#include "mock_hal.h" // Traditional mocking still available

// Make all functions in the sensor module available for direct testing
#include TEST_PARTIAL_ALL_MODULE(sensor)

// Test the `static` conversion helper internal to source module under test
void test_ConvertRawToMilliCelsius(void)
{
    // `_ConvertRawToMilliCelsius()` is accessible in the Partial 
    // linked in this test executable build
    TEST_ASSERT_EQUAL_INT(-40000, _ConvertRawToMilliCelsius(0));
}
```

#### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h` and extracts all function definitions.
1. `TEST_PARTIAL_ALL_MODULE()` instructs Partial generation to gather and 
   expose all functions from the `sensor` module to be made testable.
1. Generates `ceedling_partial_sensor_impl.c` containing all source functions
   including `_ConvertRawToMilliCelsius()` (stripped of `static` decorator).
1. Compiles and links the Partial implementation source (in place of the original 
   `sensor` source module) and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

### Using the mockable partial

```c
// test_sensor_partials_mocks.c -----------------------------------
#include "unity.h"
#include "ceedling.h" // Required -- defines Partial directive macros
#include "mock_hal.h" // Traditional mocking still available

// Create two complementary Partials:
//  1. All the non-static functions for testing
//  2. Mocked static functions to be used in test cases
//
// We need both Partials with non-overlapping lists of functions in
// order to separate the testable functions from the mocked functions
// extracted from the same source module.

// Make all the non-static functions available for testing
#include TEST_PARTIAL_PUBLIC_MODULE(sensor)

// Make the static helper function available as a mock
#include MOCK_PARTIAL_PRIVATE_MODULE(sensor)

// Test Sensor_ReadCelsius() using a mock of the helper function
void test_Sensor_ReadCelsius(void)
{
    // Traditional mock of external HAL interface
    HAL_SensorRead_ExpectAndReturn(1234);

    // Partial mock of `static` function internal to source module under test
    _ConvertRawToMilliCelsius_ExpectAndReturn(1234, 1000);

    TEST_ASSERT_EQUAL_INT(1, Sensor_ReadCelsius());
}
```

#### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h`, extracts all function definitions.
1. Classifies `_ConvertRawToMilliCelsius` as **private** (from the `static`
   decorator).
1. Generates `ceedling_partial_sensor_interface.h` containing only
   `_ConvertRawToMilliCelsius()`.
1. Collects all non-static functions in the `sensor` module and
   generates `ceedling_partial_sensor_impl.h` and 
   `ceedling_partial_sensor_impl.c` containing those functions segragated
   from the mockable function signature organized in (3).
1. Runs CMock on the Partial interface header to produce mock source.
1. Compiles and links the mocked Partial interface source from (3), the 
   Partial implementation source from (4) in place of the original `sensor` 
   source module, and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

<br/><br/>
