# Bullseye

This plugin measures code coverage with [Bullseye Coverage][bullseye]. It adds
a set of `bullseye:` build tasks that mirror Ceedling's `test:` tasks. Those
tasks instrument your code, run your tests, and report how much of your source
the tests actually exercised.

!!! warning "Requires a commercial license"
    Bullseye Coverage is commercial software. You need your own licensed
    installation. See [Licensing](licensing.md).

!!! note
    A `bullseye:` task is a [delta build](../../getting-started/builds.md).
    This plugin maintains its own dependency cache. Test executables and source
    files are rebuilt the first time you run a `bullseye:` build. Coverage
    instrumentation must be applied at compile time, so `bullseye:` builds
    cannot share objects with `test:` builds. See
    [Understanding plugin build duplication](../index.md#understanding-plugin-build-duplication).

---

## Plugin overview

A `bullseye:` task compiles and links test executables with Bullseye
instrumentation, runs them, and accumulates coverage data. All coverage data
lands in a single coverage data file. Reports are generated from that file.

Every `test:` task has a `bullseye:` counterpart.

```shell
 > ceedling bullseye:all
 > ceedling bullseye:Model
 > ceedling bullseye:pattern[Model*]
 > ceedling bullseye:path[controllers]
```

### Coverage metric

Bullseye measures two things. Function coverage records whether each function
was invoked at all. Condition/decision coverage is a hybrid metric. It records
whether each branch condition evaluated both true and false. It also records
whether each individual boolean operand did the same.

This plugin labels condition/decision coverage as BRANCHES in its console
output.

Bullseye's own site offers a [conceptual overview of code coverage][bullseye-coverage].
It includes suggested incremental coverage goals.

### The coverage data file

Coverage data accumulates in `test.cov` at your project root. Every
instrumented test executable writes to it. Every reporting tool reads from it.

This file lives at your project root rather than under `build/` for a specific
reason. Bullseye records each source path relative to the coverage data file's
own location. Report exclusions match against that stored path. Your project
root is the only common ancestor of every source location a project can have.
Those locations include `src/`, `test/`, vendored framework sources, and
generated test runners. Bullseye
[recommends this placement][bullseye-coverage-file] for the same reason.

Coverage data accumulates across runs. Use `ceedling clean` or
`ceedling clobber` to discard it and start fresh.

### Supported tool versions

This plugin is verified against Bullseye Coverage 9.25.9 on Linux x64. It
relies on command-line conventions that have been stable across Bullseye's
release history. Other versions are likely to work. They have not been
verified.

## Installation and set up

### Install Bullseye

Obtain an installer from [Bullseye's download page][bullseye-download]. Install
and activate it following [Licensing](licensing.md).

Bullseye's tools must be on your `PATH`. Ceedling's
[`:environment`](../../configuration/reference/environment.md) settings can
also supply the path.

!!! note "Docker images"
    Ceedling's `madsciencelab-plugins` Docker images do not include Bullseye.
    Distributing its executables requires a license that a freely available
    image cannot carry. Download Bullseye yourself, then either extend the
    image or install into a running container. See
    [Using Bullseye in a container](licensing.md#using-bullseye-in-a-container).

### Enable the plugin

Add the plugin to your Ceedling project file.

```yaml
:plugins:
  :enabled:
    - bullseye
```

This alone creates the `bullseye:` tasks and prints console coverage summaries.
No further configuration is required.

## Configuration

All settings live in a top-level `:bullseye:` section of your project file.

### `:summaries:`

Controls the coverage summaries printed to the console after `bullseye:` tasks.
Set it to `FALSE` to suppress them.

```yaml
:bullseye:
  :summaries: FALSE
```

**Default:** `TRUE`

### `:untested_sources:`

Controls how the plugin handles source files that no test exercises. It takes
one of three values.

* `:ignore` — Untested sources are not processed. Nothing is logged. Nothing
  is compiled. These files are absent from coverage reports.
* `:list` — Untested sources are not compiled. Their filepaths are logged as a
  warning so you know what is missing from reports.
* `:compile` — All untested sources are compiled with coverage. They appear in
  reports at 0% coverage. A source that fails to compile fails the build.

```yaml
:bullseye:
  :untested_sources: :list
```

**Default:** `:list`

!!! warning
    **Compiling all untested sources for 0% coverage reporting (`:compile`) will likely require additional work.**

    Successful compilation of untested source files may require certain
    symbols to be defined, certain flags to be set, or entire stand-in shims
    for platform headers and code.

    Ceedling's
    [`:defines`](../../configuration/reference/defines.md)
    and
    [`:flags`](../../configuration/reference/flags.md)
    matchers can provide these. Bullseye tasks extract symbols and flags from
    the `:test` context by default. Use the `:bullseye` context in those
    matchers to supply anything specific to coverage builds.

`:compile` also enables a standalone `bullseye:untested_sources` task.

```shell
 > ceedling bullseye:untested_sources
```

This task recompiles only the untested sources. It exists so you can work
through the compilation problems above without rebuilding the whole test suite
each time.

### `:branch_detail:`

Prints an annotated source listing identifying individual uncovered branches.
Console summaries report branch coverage only as a percentage. This setting is
the only console report that shows which branches account for that number.

It takes one of three values.

* `:none` — No annotated listing.
* `:uncovered` — Annotate only probes that are not fully covered.
* `:all` — Annotate every source line.

```yaml
:bullseye:
  :branch_detail: :uncovered
```

**Default:** `:none`

See [Branch coverage detail](#branch-coverage-detail) for how to read the
output.

### `:xml_report:`

Generates a machine-readable coverage report for CI tooling. It takes one of
three values.

* `:none` — No XML report.
* `:native` — Bullseye's own XML schema.
* `:cobertura` — Cobertura format, which many CI dashboards already read.

```yaml
:bullseye:
  :xml_report: :cobertura
```

**Default:** `:none`

The report is written to `build/artifacts/bullseye/coverage.xml`.

### `:fail_under:`

Fails the build when coverage falls below a minimum percentage. Each metric is
configured separately. A value of `0` disables that check.

```yaml
:bullseye:
  :fail_under:
    :functions: 90
    :branches: 75
```

**Default:** `0` for both metrics

Reports are still generated when a threshold is unmet. The failure is reported
last so you see the coverage numbers first.

```
------------------------
❌ BUILD FAILURE SUMMARY
------------------------
 • [BULLSEYE] Function coverage 50% is below the configured minimum of 90%.
 • [BULLSEYE] Branch coverage 10% is below the configured minimum of 75%.
```

### `:report_task:`

Controls whether reports generate automatically. By default, HTML and XML
reports are generated after every `bullseye:` task. Set this to `TRUE` to
generate them on demand instead.

```yaml
:bullseye:
  :report_task: TRUE
```

**Default:** `FALSE`

This setting enables a `report:bullseye` task.

```shell
 > ceedling bullseye:all
 > ceedling report:bullseye
```

Large projects may prefer this. Report generation can be time intensive.

### `:license_manager_file:`

Points the plugin at a shared Bullseye license manager file. This applies only
to floating and evaluation licenses. See
[Licensing](licensing.md#floating-and-evaluation-licenses).

```yaml
:bullseye:
  :license_manager_file: /path/to/shared/bullseye.lmgr
```

**Default:** unset

## Reporting

Bullseye is a single self-contained toolchain. This plugin has no `:reports:`
list to configure and no choice of reporting utility. Ceedling's `gcov` plugin
differs here because it supports three interchangeable report tools.

### Console summaries

Two summaries print after a `bullseye:` task. Per-function detail lists each
function's invocation status and condition/decision coverage. Whole-file totals
follow as a single banner.

```
-------------------------------
BULLSEYE: CODE COVERAGE SUMMARY
-------------------------------
calc_never_used(int,int)       0 / 1 =   0%   0 /  6 =   0%
calc_classify(int)             1 / 1 = 100%   1 /  4 =  25%
------------------------  -----------------  --------------
Total                          1 / 2 =  50%   1 / 10 =  10%

-------------------------------
BULLSEYE: CODE COVERAGE SUMMARY
-------------------------------
FUNCTIONS: 50%
BRANCHES:  10%
```

The totals banner covers every function and branch recorded in the coverage
data file. It is not limited to what the current task invocation touched.

### Branch coverage detail

Enabling [`:branch_detail:`](#branch_detail) adds an annotated source listing.
Each probe is marked to the left of its source line.

```
--------------------------------
BULLSEYE: BRANCH COVERAGE DETAIL
--------------------------------
src/calc.c:
        1 #include "calc.h"
        2
X       3 int calc_classify(int n) {
-->T    4   if (n > 10) { return 1; }
-->     5   else if (n < 0) { return -1; }
        6   return 0;
        7 }
        8
-->     9 int calc_never_used(int a, int b) {
-->    10   if (
  -->           a &&
  -->                b) { return 1; }
       11   return 0;
       12 }
```

The markers carry specific meanings.

| Marker | Meaning |
|---|---|
| `X` | An executed function, switch label, try block, or loop body |
| `T` | A decision that evaluated true |
| `F` | A decision that evaluated false |
| `t` | A condition within a decision that evaluated true |
| `f` | A condition within a decision that evaluated false |
| `-->` | Incomplete coverage |
| `/` | An excluded probe |

Several probes on one line are distinguished by letter suffixes such as `19a`
and `19b`.

### HTML reports

A full interactive HTML report is generated to
`build/artifacts/bullseye/covhtml/`. Open `index.html` in a browser.

### XML reports

Enabling [`:xml_report:`](#xml_report) writes
`build/artifacts/bullseye/coverage.xml`. Cobertura format suits CI dashboards
that already consume it. Bullseye's native schema carries more detail,
including per-probe results.

### Report exclusions

Framework and test sources are excluded from reports automatically. Unity,
CMock, CException, files matching your test file prefix, and generated mocks
are all excluded. Aggregate percentages therefore reflect your production code.

Exclusions apply to console totals, HTML reports, and XML reports alike.

Bullseye calls the underlying concept a region. A region is an inclusion or
exclusion rule. Regions can match by filename, directory, function, or C++
class and namespace. This plugin uses filename-pattern exclusions only. See
[Bullseye's region reference][bullseye-regions] for the full syntax.

## Additional tasks

### Coverage Browser

The `utils:bullseye` task opens Bullseye's graphical Coverage Browser against
your project's coverage data file.

```shell
 > ceedling utils:bullseye
```

### License status

The `utils:bullseye_license` task reports your Bullseye license number, its
expiry date, and license manager utilization.

```shell
 > ceedling utils:bullseye_license
```

See [Licensing](licensing.md) for how to read its output.

## Advanced and troubleshooting

### Advanced usage

This plugin's tool definitions and defaults are contained in
[defaults_bullseye.rb](../../snapshot/plugins/bullseye/config/defaults_bullseye.rb)
and [defaults.yml](../../snapshot/plugins/bullseye/config/defaults.yml). Both
are useful references for overriding plugin behavior with Ceedling's advanced
features.

### Tool wrapping and custom flags

This plugin's compiler and linker tools wrap `gcc` with Bullseye's `covc`.
`covc` parses everything before the wrapped compiler's name as its own option.
Anything after that name is passed through to the compiler.

The wrapped compiler name is therefore folded into each tool's `:executable`
setting as `covc -q gcc`. It is not left as a leading argument.

Keep this ordering in mind when overriding `:bullseye_compiler` or
`:bullseye_linker`. Your own `:arguments:` entries must land after the wrapped
compiler's name. So must any flags Ceedling injects through `:defines` and
`:flags` matchers.

### "unknown option" errors from `covc`

A flag that belongs to `gcc` landed before the wrapped compiler's name. See
[Tool wrapping and custom flags](#tool-wrapping-and-custom-flags).

### `utils:bullseye` fails to launch `CoverageBrowser`

`CoverageBrowser` is a GUI application with its own runtime dependencies. GTK
is one example on Linux. Install your platform's GUI toolkit dependencies
alongside Bullseye.

Headless environments rarely have these libraries. Console summaries, HTML
reports, and XML reports have no GUI dependencies at all.

### Relocating the coverage data file

Region-based exclusions may stop matching if you relocate the coverage data
file through your own `:tools:` overrides. See
[The coverage data file](#the-coverage-data-file) for why its location
matters.

[bullseye]:                  https://www.bullseye.com
[bullseye-coverage]:         https://www.bullseye.com/coverage.html
[bullseye-coverage-file]:    https://www.bullseye.com/help/build-coverageFile.html
[bullseye-download]:         https://www.bullseye.com/cgi-bin/download
[bullseye-regions]:          https://www.bullseye.com/help/ref-regions.html

<br/><br/>
