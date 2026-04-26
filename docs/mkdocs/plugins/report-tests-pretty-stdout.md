# Ceedling Plugin: Pretty Test Suite Console Report

Prints to the console ($stdout) simple, readable test suite results.

# Plugin Overview

This plugin is intended to be the default option for formatting a test suite's
results when displayed at the console. It collects raw test results from the 
individual test executables of your test suite and presents them in a more 
readable summary form.

# Setup

Enable the plugin in your project.yml by adding `report_tests_pretty_stdout` to 
the list of enabled plugins instead of any other `report_tests_*_stdout` 
plugin.

``` YAML
:plugins:
  :enabled:
    - report_tests_pretty_stdout
```

# Configuration

No additional configuration is needed once the plugin is enabled.

# Example Output

```sh
 > ceedling test:Model
```

```
-------------------
FAILED TEST SUMMARY
-------------------
[test/TestModel.c]
  Test: testInitShouldCallSchedulerAndTemperatureFilterInit
  At line (21): "Function TaskScheduler_Init() called more times than expected."

--------------------
OVERALL TEST SUMMARY
--------------------
TESTED:  1
PASSED:  0
FAILED:  1
IGNORED: 0

---------------------
BUILD FAILURE SUMMARY
---------------------
Unit test failures.
```
