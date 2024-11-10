# A Fake Function Framework Plug-in for Ceedling

This is a plug-in for [Ceedling](https://github.com/ThrowTheSwitch/Ceedling) to use the [Fake Function Framework](https://github.com/meekrosoft/fff) for mocking instead of CMock.

Using fff provides less strict mocking than CMock, and can allow for more loosely-coupled tests.

### Thanks

A special thanks to [Matt Chernosky](http://www.electronvector.com) for developing this plugin originally. It's a well-loved piece of the Ceedling 
ecosystem and we really appreciate his support through the years.

### Enable the plug-in.

The plug-in is enabled from within your project.yml file.

In the `:plugins` configuration, add `fff` to the list of enabled plugins:

```yaml
:plugins:
  :load_paths:
    - vendor/ceedling/plugins
  :enabled:
    - report_tests_pretty_stdout
    - module_generator
    - fff
```
*Note that you could put the plugin source in some other loaction.
In that case you'd need to add a new path the `:load_paths`.*

## How to use it

You use fff with Ceedling the same way you used to use CMock.

If you want to "mock" `some_module.h` in your tests, just `#include "mock_some_module.h"`.
This creates a fake function for each of the functions defined in `some_module.h`.

The name of each fake is the original function name with an appended `_fake`.
For example, if we're generating fakes for a stack module with `push` and `pop` functions, we would have the fakes `push_fake` and `pop_fake`.
These fakes are linked into our test executable so that any time our unit under test calls `push` or `pop` our fakes are called instead.

Each of these fakes is actually a structure containing information about how the function was called, and what it might return.
We can use Unity to inspect these fakes in our tests, and verify the interactions of our units.
There is also a global structure named `fff` which we can use to check the sequence of calls.

The fakes can also be configured to return particular values, so you can exercise the unit under test however you want.

The examples below explain how to use fff to test a variety of module interactions.
Each example uses fakes for a "display" module, created from a display.h file with `#include "mock_display.h"`. The `display.h` file must exist and must contain the prototypes for the functions to be faked.

### Test that a function was called once

```c
void
test_whenTheDeviceIsReset_thenTheStatusLedIsTurnedOff()
{
    // When
    event_deviceReset();

    // Then
    TEST_ASSERT_EQUAL(1, display_turnOffStatusLed_fake.call_count);
}
```

### Test that a function was NOT called

```c
void
test_whenThePowerReadingIsLessThan5_thenTheStatusLedIsNotTurnedOn(void)
{
    // When
    event_powerReadingUpdate(4);

    // Then
    TEST_ASSERT_EQUAL(0, display_turnOnStatusLed_fake.call_count);
}
```

## Test that a single function was called with the correct argument

```c
void
test_whenTheVolumeKnobIsMaxed_thenVolumeDisplayIsSetTo11(void)
{
    // When
    event_volumeKnobMaxed();

    // Then
    TEST_ASSERT_EQUAL(1, display_setVolume_fake.call_count);
    TEST_ASSERT_EQUAL(11, display_setVolume_fake.arg0_val);
}
```

## Test that calls are made in a particular sequence

```c
void
test_whenTheModeSelectButtonIsPressed_thenTheDisplayModeIsCycled(void)
{
    // When
    event_modeSelectButtonPressed();
    event_modeSelectButtonPressed();
    event_modeSelectButtonPressed();

    // Then
    TEST_ASSERT_EQUAL_PTR((void*)display_setModeToMinimum, fff.call_history[0]);
    TEST_ASSERT_EQUAL_PTR((void*)display_setModeToMaximum, fff.call_history[1]);
    TEST_ASSERT_EQUAL_PTR((void*)display_setModeToAverage, fff.call_history[2]);
}
```

## Fake a return value from a function

```c
void
test_givenTheDisplayHasAnError_whenTheDeviceIsPoweredOn_thenTheDisplayIsPoweredDown(void)
{
    // Given
    display_isError_fake.return_val = true;

    // When
    event_devicePoweredOn();

    // Then
    TEST_ASSERT_EQUAL(1, display_powerDown_fake.call_count);
}
```

## Fake a function with a value returned by reference

```c
void
test_givenTheUserHasTypedSleep_whenItIsTimeToCheckTheKeyboard_theDisplayIsPoweredDown(void)
{
    // Given
    char mockedEntry[] = "sleep";
    void return_mock_value(char * entry, int length)
    {
        if (length > strlen(mockedEntry))
        {
            strncpy(entry, mockedEntry, length);
        }
    }
    display_getKeyboardEntry_fake.custom_fake = return_mock_value;

    // When
    event_keyboardCheckTimerExpired();

    // Then
    TEST_ASSERT_EQUAL(1, display_powerDown_fake.call_count);
}
```

## Fake a function with a function pointer parameter

```
void
test_givenNewDataIsAvailable_whenTheDisplayHasUpdated_thenTheEventIsComplete(void)
{
    // A mock function for capturing the callback handler function pointer.
    void(*registeredCallback)(void) = 0;
    void mock_display_updateData(int data, void(*callback)(void))
    {
        //Save the callback function.
        registeredCallback = callback;
    }
    display_updateData_fake.custom_fake = mock_display_updateData;

    // Given
    event_newDataAvailable(10);

    // When
    if (registeredCallback != 0)
    {
        registeredCallback();
    }

    // Then
    TEST_ASSERT_EQUAL(true, eventProcessor_isLastEventComplete());
}
```

## Helper macros

For convenience, there are also some helper macros that create new Unity-style asserts:

- `TEST_ASSERT_CALLED(function)`: Asserts that a function was called once.
- `TEST_ASSERT_NOT_CALLED(function)`: Asserts that a function was never called.
- `TEST_ASSERT_CALLED_TIMES(times, function)`: Asserts that a function was called a particular number of times.
- `TEST_ASSERT_CALLED_IN_ORDER(order, function)`: Asserts that a function was called in a particular order.

Here's how you might use one of these instead of simply checking the call_count value:

```c
void
test_whenTheDeviceIsReset_thenTheStatusLedIsTurnedOff()
{
    // When
    event_deviceReset();

    // Then
    // This how to directly use fff...
    TEST_ASSERT_EQUAL(1, display_turnOffStatusLed_fake.call_count);
    // ...and this is how to use the helper macro.
    TEST_ASSERT_CALLED(display_turnOffStatusLed);
}
```

## Test setup

All of the fake functions, and any fff global state are all reset automatically between each test.

## CMock configuration

Use still use some of the CMock configuration options for setting things like the mock prefix, and for including additional header files in the mock files.

```yaml
:cmock:
    :mock_prefix: mock_
        :includes:
            -
        :includes_h_pre_orig_header:
            -
        :includes_h_post_orig_header:
            -
        :includes_c_pre_header:
            -
        :includes_c_post_header:
```

## Running the tests

There are unit and integration tests for the plug-in itself.
These are run with the default `rake` task.
The integration test runs the tests for the example project in examples/fff_example.
For the integration tests to succeed, this repository must be placed in a Ceedling tree in the plugins folder.

## More examples

There is an example project in examples/fff_example.
It shows how to use the plug-in with some full-size examples.
