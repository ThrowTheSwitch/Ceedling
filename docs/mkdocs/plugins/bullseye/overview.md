# Plugin Overview

!!! note
    When enabled, this plugin creates a new set of `bullseye:` tasks that
    mirror Ceedling's existing `test:` tasks. A `bullseye:` task compiles and
    links test executables with Bullseye instrumentation, executes them, and
    accumulates coverage data in a shared coverage data file.

    `bullseye:` tasks entirely duplicate `test:` tasks and test builds because
    of the needs of coverage instrumentation at compile time.

## Coverage Metric

Bullseye measures **function coverage** (whether each function was invoked at
all) and **condition/decision coverage** — a hybrid metric combining decision
coverage (whether each branch condition evaluated both true and false) and
condition coverage (whether each individual boolean operand did the same).
Bullseye's own site has a good [conceptual overview of code coverage][bullseye-coverage]
and this specific metric, including suggested incremental coverage goals.

[bullseye-coverage]: https://www.bullseye.com/coverage.html

## Console Summaries

By default, this plugin prints coverage information to the console after
every `bullseye:` task run — no report configuration is required. Other than
enabling the plugin and having a licensed Bullseye installation available,
no further set up is necessary to produce these summaries.

!!! tip
    [Console summaries may be disabled](setup.md#disabling-console-summaries).

When the Bullseye plugin is active it enables Ceedling tasks like this:

```shell
 > ceedling bullseye:Model
```

… that then print, after the standard Ceedling test results summary:

- A per-source, per-function coverage detail dump.
- A whole-coverage-file functions/branches totals banner.

```
---------------------------------
BULLSEYE: ✅ OVERALL TEST SUMMARY
---------------------------------
TESTED:  1
PASSED:  1
FAILED:  0
IGNORED: 0

-------------------------------
BULLSEYE: CODE COVERAGE SUMMARY
-------------------------------
Model_Init(void)       1 / 1 = 100%  0 / 0
Model_Update(int)      1 / 1 = 100%  2 / 2 = 100%
------------------  -----------------  ------------
Total                  2 / 2 = 100%  2 / 2 = 100%

-------------------------------
BULLSEYE: CODE COVERAGE SUMMARY
-------------------------------
FUNCTIONS: 100%
BRANCHES:  100%
```

## HTML Reports

For a richer, browsable view of coverage results, this plugin also supports
generating a full interactive HTML report from the accumulated coverage data.

In the default configuration, this report is generated automatically in the
build's `artifacts/` directory after each execution of a `bullseye:` task.

An optional setting documented in [Set Up & Configuration](setup.md) disables
automatic report generation, providing a separate Ceedling task instead so
reports can be generated on demand after test suite runs.

## Report Exclusions

Framework and test sources are automatically excluded from the aggregate
totals shown in both console summaries and HTML reports, so coverage
percentages reflect your production code, not Unity, CMock, CException, or
your test files themselves. See [Reporting](reporting.md#report-exclusions)
for details.

## Untested Sources

Ceedling can also optionally compile source files that no test exercises at
all, so they appear in coverage reporting at 0% rather than being silently
absent. See [Set Up & Configuration](setup.md#coverage-for-untested-sources).

<br/><br/>
