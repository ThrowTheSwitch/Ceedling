# Ceedling Plugin: GTest-like Test Suite Console Report

Prints to the console ($stdout) test suite results in a GTest-like format.

# Plugin Overview

This plugin is intended to be used in place of the more commonly used "pretty" 
test report plugin. Like its sibling, this plugin ollects raw test results from
the individual test executables of your test suite and presents them in a more 
readable summary form — specifically the GoogleTest format.

This plugin is most useful when using an IDE or working with a CI system that
understands the GTest console logging format.

# Setup

Enable the plugin in your Ceedling project by adding 
`report_tests_gtestlike_stdout` to the list of enabled plugins instead of any 
other `report_tests_*_stdout` plugin.

```YAML
:plugins:
  :enabled:
    - report_tests_gtestlike_stdout
```

# Configuration

No additional configuration is needed once the plugin is enabled.

# Plugin Output

## Ceedling mapped to GoogleTest reporting elements

Ceedling's conventions and output map to GTest format as the following:

* A Ceedling test file — ultimately an individual test executable — is a GTest 
  _test case_.
* A Ceedling test case (a.k.a. unit test) is a GTest _test_.
* Execution time is collected for each Ceedling test executable, not each 
  Ceedling test case. As such, the test report includes only execution time for
  each GTest _test case_. Individual test execution times are reported as 0 ms.

GoogleTest generates reporting output incrementally. Ceedling produces test 
results incrementally as well, but its plugin reporting structure does not 
collect and format statistics until the end of a build. This plugin duplicates
the tense of the wording in a GTest report, but it is unintentionally somewhat 
misleading.

## Example output (snippet)

The GTest format is verbose. It lists all tests with success and failure results.

The example output below shows the header and footer of test results for a suite 
of 49 Ceedling tests in 18 test files but only includes logging for 6 tests.

```sh
 > ceedling test:all
```

```
[==========] Running 49 tests from 18 test cases.
[----------] Global test environment set-up.
 
 ...

[----------] 4 tests from test/TestUsartModel.c
[ RUN      ] test/TestUsartModel.c.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting
[       OK ] test/TestUsartModel.c.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting (0 ms)
[ RUN      ] test/TestUsartModel.c.testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately
[       OK ] test/TestUsartModel.c.testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately (0 ms)
[ RUN      ] test/TestUsartModel.c.testShouldReturnErrorMessageUponInvalidTemperatureValue
[       OK ] test/TestUsartModel.c.testShouldReturnErrorMessageUponInvalidTemperatureValue (0 ms)
[ RUN      ] test/TestUsartModel.c.testShouldReturnWakeupMessage
[       OK ] test/TestUsartModel.c.testShouldReturnWakeupMessage (0 ms)
[----------] 4 tests from test/TestUsartModel.c (1277 ms total)
[----------] 1 tests from test/TestMain.c
[ RUN      ] test/TestMain.c.testMainShouldCallExecutorInitAndContinueToCallExecutorRunUntilHalted
[       OK ] test/TestMain.c.testMainShouldCallExecutorInitAndContinueToCallExecutorRunUntilHalted (0 ms)
[----------] 1 tests from test/TestMain.c (1351 ms total)
[----------] 1 tests from test/TestModel.c
[ RUN      ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit
test/TestModel.c(21): error: Function TaskScheduler_Init() called more times than expected.
 Actual:   FALSE
 Expected: TRUE
[  FAILED  ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit (0 ms)
[----------] 1 tests from test/TestModel.c (581 ms total)

[----------] Global test environment tear-down.
[==========] 49 tests from 18 test cases ran.
[  PASSED  ] 48 tests.
[  FAILED  ] 1 tests, listed below:
[  FAILED  ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit

 1 FAILED TESTS
```
