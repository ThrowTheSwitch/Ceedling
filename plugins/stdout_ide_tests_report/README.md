# Ceedling Plugin: IDE Tests Report

# Overview

This plugin is intended to be used in place of the more commonly used "pretty" 
test report plugin. Like its sibling, this plugin ollects raw test results from
the individual test executables of your test suite and presents them in a more 
readable summary form.

The format of test results produced by this plugin is identical to its prettier
sibling with one key difference — test failures are listed in such a way that 
filepaths, line numbers, and test case function names can be easily parsed by 
a typical IDE. The formatting of test failure messages uses a simple, defacto 
standard of a sort recognized almost universally.

The end result is that test failures in your IDE's build window can become 
links that jump directly to failing test cases.

# Example Output

```
-------------------
FAILED TEST SUMMARY
-------------------
test/TestModel.c:21:testInitShouldCallSchedulerAndTemperatureFilterInit: "Function TaskScheduler_Init() called more times than expected."

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

Enable the plugin in your project.yml by adding `stdout_ide_tests_report` to 
the list of enabled plugins instead of any other `stdout_*_tests_report` 
plugin.

``` YAML
:plugins:
  :enabled:
    - stdout_ide_tests_report
```
