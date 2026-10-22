# GTest-like Console Report

Prints to the console (`$stdout`) test suite results in GoogleTest’s console format.

## Plugin Overview

This plugin reports test results the way GoogleTest prints them. It is intended
to be used in place of the more commonly used "pretty" test report plugin. Like
its sibling, it collects raw test results from the individual test executables
of your test suite and presents them in summary form.

This plugin is most useful with an IDE or CI system that understands GoogleTest’s
console output. Its line formats follow GoogleTest’s own console printer, down to
singular and plural counts and the ordering of its summary.

## Setup

Enable the plugin in your Ceedling project by adding 
`report_tests_gtestlike_stdout` to the list of enabled plugins instead of any 
other `report_tests_*_stdout` plugin.

```YAML
:plugins:
  :enabled:
    - report_tests_gtestlike_stdout
```

## Configuration

One setting controls how the report treats ignored tests. By default, a test
ignored with Unity’s `TEST_IGNORE()` or `TEST_IGNORE_MESSAGE()` is reported as a
GoogleTest skipped test.

```YAML
:report_tests_gtestlike_stdout:
  :ignored_as_skipped: TRUE    # Default
```

Set it to `FALSE` to leave ignored tests out of the report. Ignored tests are
then neither listed nor counted, and a test file whose every test is ignored has
no section at all. The rest of the report is unchanged.

## GoogleTest and Ceedling concepts

GoogleTest and Ceedling describe a test suite in different terms. This table maps
each GoogleTest concept to its Ceedling and Unity counterpart and to this plugin’s
console output.

| GoogleTest | Ceedling & Unity | In this report |
|---|---|---|
| Test suite | A test file, built into one test executable | A `[----------] N tests from <test file>` section |
| Test | A Unity test case in that test file | `<test file>.<test case>` |
| Passed test (`[       OK ]`) | A passing test case | Listed and counted as passed |
| Failed test (`[  FAILED  ]`) | A failing test case | Listed with its `file(line)` location and counted as failed |
| Skipped test (`GTEST_SKIP()`, `[  SKIPPED ]`) | `TEST_IGNORE()` or `TEST_IGNORE_MESSAGE()` | Listed and counted as skipped, or left out with `:ignored_as_skipped: FALSE` |
| Disabled test (`DISABLED_` prefix) | No equivalent | Never reported |
| Per-test time | Not measured; Ceedling times each test executable | Each test reports `0 ms`; each section reports its file’s time |
| Incremental output | Results are collected at the end of a build | The full report prints once the build ends |

An ignored Unity test is a skipped GoogleTest test, not a disabled one. Unity
decides to ignore a test at runtime. `setUp()` runs, the test body begins,
`TEST_IGNORE()` ends it, and `tearDown()` runs. That is what `GTEST_SKIP()` does.
A GoogleTest `DISABLED_` test never runs at all.

Tests that never run never reach Ceedling’s results. Test cases excluded by the
`--test-case` or `--exclude-test-case` command line filters, or hidden by the
preprocessor, therefore never appear in this report. They are not reported as
disabled tests.

Each section lists its tests in source order. Skipped tests count toward the
run’s total and its suite count. The summary reports passed, then skipped, then
failed tests, as GoogleTest does. It lists skipped and failed tests only when
there are any.

## GoogleTest skip support and its consumers

GoogleTest added skipped tests in version 1.10.0, released in October 2019.
That release introduced `GTEST_SKIP()` along with the `[  SKIPPED ]` lines in
its console output. Earlier versions have no skipped outcome.

Tools that read GoogleTest output may not understand skipped tests. Some predate
GoogleTest 1.10.0, and others added support only later. LLVM’s `lit` test runner,
for example, added explicit handling for skipped GoogleTest tests in 2021. A tool
written for older output may treat a `[  SKIPPED ]` line as unknown or may report
a skipped test as passed.

Which tools parse this plugin’s output is unknown. If yours misreads skipped
tests, set `:ignored_as_skipped: FALSE` to restore a report without them.

## Plugin Output

The GoogleTest format is verbose. It lists every test with its result, then
summarizes the run.

### Example output

The example below reports a suite of 5 tests in 3 test files. One test passes
alongside a skipped test in its file, and one test fails.

```sh
 > ceedling test:all
```

```
[==========] Running 5 tests from 3 test suites.
[----------] Global test environment set-up.
[----------] 2 tests from test/TestUsartModel.c
[ RUN      ] test/TestUsartModel.c.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting
[       OK ] test/TestUsartModel.c.testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting (0 ms)
[ RUN      ] test/TestUsartModel.c.testShouldReturnWakeupMessage
[       OK ] test/TestUsartModel.c.testShouldReturnWakeupMessage (0 ms)
[----------] 2 tests from test/TestUsartModel.c (1277 ms total)

[----------] 2 tests from test/TestTimerConductor.c
[ RUN      ] test/TestTimerConductor.c.testInitShouldCallHardwareAndInterruptInit
[       OK ] test/TestTimerConductor.c.testInitShouldCallHardwareAndInterruptInit (0 ms)
[ RUN      ] test/TestTimerConductor.c.testRunShouldHandleTimerOverflow
test/TestTimerConductor.c(34): Skipped
Waiting on driver rewrite

[  SKIPPED ] test/TestTimerConductor.c.testRunShouldHandleTimerOverflow (0 ms)
[----------] 2 tests from test/TestTimerConductor.c (402 ms total)

[----------] 1 test from test/TestModel.c
[ RUN      ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit
test/TestModel.c(21): error: Function TaskScheduler_Init() called more times than expected.
 Actual:   FALSE
 Expected: TRUE
[  FAILED  ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit (0 ms)
[----------] 1 test from test/TestModel.c (581 ms total)

[----------] Global test environment tear-down
[==========] 5 tests from 3 test suites ran. (2260 ms total)
[  PASSED  ] 3 tests.
[  SKIPPED ] 1 test, listed below:
[  SKIPPED ] test/TestTimerConductor.c.testRunShouldHandleTimerOverflow
[  FAILED  ] 1 test, listed below:
[  FAILED  ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit

 1 FAILED TEST
```

A skipped test prints its location and its `TEST_IGNORE_MESSAGE()` text, then a
blank line and its result. A test ignored with `TEST_IGNORE()` has no message,
so its message line is absent.

A run in which every test passes ends at its `[  PASSED  ]` line. The failure
list and its trailer appear only when a test fails.

### Example output with ignored tests left out

The same suite with `:ignored_as_skipped: FALSE` reports 4 tests. The ignored
test is gone from its section, from the counts, and from the summary.

```
[==========] Running 4 tests from 3 test suites.

 ...

[----------] 1 test from test/TestTimerConductor.c
[ RUN      ] test/TestTimerConductor.c.testInitShouldCallHardwareAndInterruptInit
[       OK ] test/TestTimerConductor.c.testInitShouldCallHardwareAndInterruptInit (0 ms)
[----------] 1 test from test/TestTimerConductor.c (402 ms total)

 ...

[----------] Global test environment tear-down
[==========] 4 tests from 3 test suites ran. (2260 ms total)
[  PASSED  ] 3 tests.
[  FAILED  ] 1 test, listed below:
[  FAILED  ] test/TestModel.c.testInitShouldCallSchedulerAndTemperatureFilterInit

 1 FAILED TEST
```

<br/><br/>
