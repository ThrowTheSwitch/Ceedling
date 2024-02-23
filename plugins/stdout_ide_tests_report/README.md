# Ceedling Plugin: IDE Test Suite Console Report

Prints to the console ($stdout) test suite results with a test failure filepath and line number format understood by nearly any IDE.

# Plugin Overview

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

# Setup

Enable the plugin in your project.yml by adding `report_tests_ide_stdout` to 
the list of enabled plugins instead of any other `report_tests_*_stdout` 
plugin.

``` YAML
:plugins:
  :enabled:
    - report_tests_ide_stdout
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

