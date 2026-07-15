# Set Up & Configuration

## Toolchain dependencies

This plugin relies on a licensed Bullseye Coverage installation. Coverage
instrumentation is applied by wrapping your compiler and linker invocations
with Bullseye's `covc` tool; instrumented test executables write coverage
data to a coverage data file (`test.cov` at your project root by default) as
they run. `covsrc`, `covfn`, `covhtml`, and `covselect` all read from that
same file to produce console summaries, HTML reports, and report exclusions.

See [Licensing](licensing.md) for how to obtain and install Bullseye
Coverage. Unlike this project's `gcov` plugin, the `madsciencelab` Docker
images do not include Bullseye pre-installed — it's commercial software
requiring its own license, so it cannot be bundled into a general-purpose,
freely distributable image.

## Enable this plugin

To use this plugin it must be enabled in your Ceedling project file:

```yaml
:plugins:
  :enabled:
    - bullseye
```

This simple configuration will create new `bullseye:` command line tasks to
run tests with source coverage and output console coverage summaries as
described in [Overview](overview.md).

## Disabling console summaries

To disable the coverage summaries printed immediately following `bullseye:`
tasks, add the following to a top-level `:bullseye:` section in your project
configuration file.

```yaml
:plugins:
  :enabled:
    - bullseye

:bullseye:
  :summaries: FALSE
```

**Default:** `TRUE`

## Coverage for untested sources

This setting controls how the plugin handles project source files that are
not exercised by any test. It takes one of three values:

* `:ignore` — Untested source files are not processed at all. Nothing is
  logged, nothing is compiled, and these files are simply absent from the
  coverage report.
* `:list` — Untested source files are not compiled with coverage, but their
  filepaths are logged as a warning so you know which files will not appear
  in the coverage report.
* `:compile` — All untested source files are compiled with coverage so they
  appear in the final report with 0% coverage (since no test exercises
  them). This causes all source files to appear in any generated reporting.
  If a source file fails to compile, Ceedling logs guidance at the console,
  and the build fails.

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
    matchers can provide these. For Bullseye tasks, symbols and flags are
    extracted from the `:test` context beneath the `:defines` and `:flags`
    configuration sections by default. If you need something special for
    coverage builds, use the `:bullseye` context for these matchers instead.

When `:untested_sources` is `:compile`, an additional `bullseye:untested_sources`
build task becomes available:

```shell
 > ceedling bullseye:untested_sources
```

This task exists to let you work through the compilation problems described
in the warning above — missing symbols, flags, or platform header/code
stand-ins — by re-running just the untested-source compilation step
directly. No test suite build is needed while iterating on source compilation
fixes.

## Automatic and manual HTML report generation

By default, this plugin automatically generates an HTML coverage report
after any `bullseye:` task is executed. To disable this behavior, add
`:report_task: TRUE` to your project file's `:bullseye:` configuration.

With this setting enabled, an additional Ceedling task `report:bullseye` is
enabled. It may be executed after `bullseye:` tasks to generate the HTML
report on demand.

For small projects, the default behavior is likely preferred. This
alternative setting allows large or complex projects to skip potentially
time-intensive report generation except when desired.

```yaml
:bullseye:
  :report_task: TRUE
```
**Default:** `FALSE`

## Coverage Browser

Independent of `bullseye:` tasks, this plugin's `utils:bullseye` task opens
Bullseye's graphical Coverage Browser against your project's current
coverage data file:

```shell
 > ceedling utils:bullseye
```

This requires Bullseye's `CoverageBrowser` GUI tool and its own dependencies
(e.g. GTK on Linux) to be present in your environment — see
[Troubleshooting](troubleshooting.md).

<br/><br/>
