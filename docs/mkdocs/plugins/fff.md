# Fake Function Framework for Ceedling

This plugin causes Ceedling to use the [Fake Function Framework](https://github.com/meekrosoft/fff) for mocking instead of CMock, the default mocking framework packaged with Ceedling.

Using _FFF_ provides less strict mocking than CMock and affords more loosely-coupled tests.

This Ceedling 1.x plugin incorporates a snapshot of _FFF_ version 0.1.1 and supersedes a separately available [FFF Ceedling plugin project](https://github.com/ElectronVector/fake_function_framework). The built-in _FFF_ plugin that now comes with Ceedling was derived from the ElectronVector project and is now maintained along with Ceedling and tracks its updates.

!!! note "Special thanks to Matt Chernosky"
    [Matt Chernosky](http://www.electronvector.com) originally developed this plugin 
    as an adapter for _FFF_. It's a well-loved piece of the Ceedling ecosystem,
    and we really appreciate his support through the years.

## Enable the plugin

The plugin is enabled from within your project.yml file.

In the `:plugins` configuration, add `fff` to the list of enabled plugins:

```yaml
:plugins:
  :enabled:
    - fff
```

## How to use

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

### Test that a single function was called with the correct argument

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

### Test that calls are made in a particular sequence

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

### Fake a return value from a function

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

### Fake a function with a value returned by reference

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

### Fake a function with a function pointer parameter

```c
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

All of the fake functions and any fff global state are all reset automatically between each test.

## CMock configuration

We still use some CMock configuration options for setting things like the mock prefix and for including additional header files in the mock files.

```yaml
:cmock:
    :mock_prefix: mock_
        :includes:
            - ...
        :includes_h_pre_orig_header:
            - ...
        :includes_h_post_orig_header:
            - ...
        :includes_c_pre_header:
            - ...
        :includes_c_post_header:
```

## FFF examples

See the [FFF example project][fff-example-project]. This project illustrates how to use the plugin with full-size examples.

!!! warning "Versioning"
    The example project link is to the latest in the repository.
    It is not explicitly versioned to correspond to this documentation.
    That said, FFF and the plugin are relatively stable.

### Running example tests

Unit and integration tests exist for the plugin itself.

These tests are run with the default `rake` task packaged in the [FFF plugin][fff-plugin].

The integration test runs the FFF-based unit tests within the [example project][fff-example-project].
That is, the FFF examples are executed as part of Ceedling continuous integration.

[fff-example-project]: https://github.com/ThrowTheSwitch/Ceedling/tree/master/plugins/fff/examples/fff_example
[fff-plugin]:          https://github.com/ThrowTheSwitch/Ceedling/tree/master/plugins/fff

<br/><br/>
