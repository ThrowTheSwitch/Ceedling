# Partials Walk-Through Example

!!! tip "Configuring Partials"
    Before writing test files that use Partials, see [Configuring Partials](configuration.md)
    to enable the feature in your project and learn how to configure Partials.

## Temperature sensor module

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

## Testing & mocking a `static` helper

!!! tip
    Ceedling comes with example projects. The example project `wondrous_forest`
    demonstrates the use of Partials in realistic code.
    Use [`ceedling example`](../../getting-started/command-line.md#ceedling-application-commands)
    to export the `wondrous_forest` project.

You as a test author want to:

1. Test the `static` helper `_ConvertRawToMilliCelsius()` directly
2. Mock the `static` helper `_ConvertRawToMilliCelsius()` while testing `Sensor_ReadCelsius()`

Partials allows you to accomplish both of these goals with no changes to
_sensor.c_ even though `_ConvertRawToMilliCelsius()` is static.

!!! warning "A function cannot be both tested and mocked in the same test file"
    A core restriction of the C language remains here! `_ConvertRawToMilliCelsius()`
    cannot be both tested and mocked in the same test. Attempting to do so would
    duplicate the function and cause a doubly-defined symbol failure during linking.

    We solve this by simply creating two peer test files for the different Partials
    usage scenarios.

## Using the testable partial

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

### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h` and extracts all function definitions.
1. `TEST_PARTIAL_ALL_MODULE()` instructs Partial generation to gather and 
   expose all functions from the `sensor` module to be made testable.
1. Generates `ceedling_partial_sensor_impl.c` containing all source functions
   including `_ConvertRawToMilliCelsius()` (stripped of `static` decorator).
1. Compiles and links the Partial implementation source (in place of the original 
   `sensor` source module) and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

## Using the mockable partial

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

### Partials processing step-by-step

1. Reads `sensor.c` and `sensor.h`, extracts all function definitions.
1. Classifies `_ConvertRawToMilliCelsius` as **private** (from the `static`
   decorator).
1. Generates `ceedling_partial_sensor_interface.h` containing only
   `_ConvertRawToMilliCelsius()`.
1. Collects all non-static functions in the `sensor` module and
   generates `ceedling_partial_sensor_impl.h` and 
   `ceedling_partial_sensor_impl.c` containing those functions segregated
   from the mockable function signature organized in (3).
1. Runs CMock on the Partial interface header to produce mock source.
1. Compiles and links the mocked Partial interface source from (3), the 
   Partial implementation source from (4) in place of the original `sensor` 
   source module, and the test file into the test executable. The 
   symbols and includes of `sensor.h` and `sensor.c` are duplicated in the 
   Partials while the original `sensor.c` is omitted from the build.

<br/><br/>
