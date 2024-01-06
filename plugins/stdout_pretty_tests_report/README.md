# Ceedling Plugin: Pretty Tests Report

# Plugin Overview

This plugin is intended to be the default option for formatting a test suites
results when displayed at the console. It collects raw test results from the 
individual test executables of your test suite and presents them in a more 
readable summary form.

# Example Output

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

# Configuration

Enable the plugin in your project.yml by adding `stdout_pretty_tests_report` to 
the list of enabled plugins instead of any other `stdout_*_tests_report` 
plugin.

``` YAML
:plugins:
  :enabled:
    - stdout_pretty_tests_report
```
