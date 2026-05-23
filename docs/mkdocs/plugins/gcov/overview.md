# Plugin Overview

!!! note
    When enabled, this plugin creates a new set of `gcov:` tasks that mirror
    Ceedling’s existing `test:` tasks. A `gcov:` task executes one or more tests
    with coverage enabled for the source files exercised by those tests.

    `gcov:` tasks entirely duplicate `test:` tasks and test builds because of 
    the needs of coverage instrumentation at compile time.

This plugin also provides an extensive set of options for generating various
coverage reports for your project. The simplest is text-based coverage 
summaries printed to the console after a `gcov:` test task is executed.

## Simple Coverage Summaries

In its simplest usage, this plugin outputs coverage statistics to the console
for each source file exercised by a test. These console-based coverage 
summaries are provided after the standard Ceedling test results summary. Other 
than enabling the plugin and ensuring `gcov` is installed, no further set up 
is necessary to produce these summaries.

!!! tip
    [Automatic summaries may be disabled](setup.md#disabling-automatic-coverage-summaries).

When the Gcov plugin is active it enables Ceedling tasks like this:

```shell
 > ceedling gcov:Model
```

… that then generate output like this:

```
--------------------------
GCOV: OVERALL TEST SUMMARY
--------------------------
TESTED:  1
PASSED:  1
FAILED:  0
IGNORED: 0

---------------------------
GCOV: CODE COVERAGE SUMMARY
---------------------------

TestModel
---------
Model.c | Lines executed:100.00% of 4
Model.c | No branches
Model.c | No calls
TimerModel.c | Lines executed:0.00% of 3
TimerModel.c | No branches
TimerModel.c | No calls
```

## Advanced Coverage Reports

For more advanced visualizations and reporting, this plugin also supports a 
variety of report generation options.

Advanced report generation uses [gcovr] and / or [ReportGenerator] to generate
HTML, XML, JSON, or text-based reports from coverage-instrumented test runs. 
See the tools' respective sites for examples of the reports they can generate.

In the default configuration, if reports are enabled, this plugin automatically
generates reports in the build’s `artifacts/` directory after each execution of
a `gcov:` task.

An optional setting documented below disables automatic report generation, 
providing a separate Ceedling task instead. Reports can then be generated
on demand after test suite runs.

[gcovr]: https://www.gcovr.com/
[ReportGenerator]: https://reportgenerator.io

## Summaries vs. Reports

Coverage summaries and coverage reports provide different levels of fidelity
and usability. Summaries are relatively unsophisticated while reports are 
sophisticated. As such, both provide different capabilities and levels of 
usability.

### Coverage summaries

Optional coverage summaries are intentionally simple. They require no
configuration and, to oversimplify, are largely filtered output from the `gcov`
tool.

Coverage summaries are reported to the console for each source file exercised by
the tests executed by `gcov:` tasks. That is, coverage summaries correspond to
the tests executed, and in turn, the source code that your tests call. This
could be all tests (and thus all source code) or a subset of tests (and some
subset of source code). The `gcov` tool is run multiple times after test suite
execution in direct relation to the set of tests you ran with `gcov:` testing 
tasks. In short, the scope of coverage summaries is guaranteed to match the
test suite you run.

Coverage summaries do not include any sort of grand total, final tallies. This 
is the domain of full coverage reports.

Note that Ceedling can exercise the same source code under multiple scenarios
using multiple test files. Practically, this means that the same source file
may be listed in the coverage summaries more than once. That said, its coverage
statistics will be the same each time — the aggregate result of all tests that
exercised it.

### Coverage reports

Coverage reports provide both much more detail and better overviews of coverage
than the console-based coverage summaries. However, with this comes the need
for more sophisticated configuration and certain caveats on what is reported.

Later sections detail how to configure the reports this plugin can generate.

Of note is a consequence of how reports are generated and the limits of the
tools that do so. Reports are generated using coverage results on disk. The
report generation tools slurp up the coverage results they find in the `gcov/`
build output directory. This means that previous test suite runs can "pollute"
coverage reports. The solution is simple if blunt — run the `clobber` task
before running a coverage-instrumented test suite. This will yield a coverage
report with scope that matches that of the test suite you run.

Both the `gcovr` and `reportgeneator` reporting utilities include powerful
filters that can limit the scope of reports. Hypothetically, it’s possible for
coverage reports to have the same clear scope as coverage summaries. However,
in large projects, these filters would cause impractically long command lines.
Both tools provide configuration file options that would solve the command line
problem. However, this feature is "experimental" for `gcovr` and considerable 
work to implement for both reporting utilities. At present, running 
`ceedling clobber` before generating reports is the best option to ensure 
accurate reports.

## References

Much of the text describing report generations options in this document was 
taken from the [Gcovr User Guide][gcovr-user-guide] and the
[ReportGenerator Wiki][report-generator-wiki].

The text is repeated here to provide as useful documenation as possible.

[gcovr-user-guide]: https://www.gcovr.com/en/stable/guide.html
[report-generator-wiki]: https://github.com/danielpalme/ReportGenerator/wiki

<br/><br/>
