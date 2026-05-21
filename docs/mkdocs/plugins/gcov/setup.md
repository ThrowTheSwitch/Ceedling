# Set up & Configuration

## Toolchain dependencies

### GNU Compiler Collection

This plugin relies on the GNU compiler collection. Coverage instrumentation
is enabled through `gcc` compiler flags. Coverage-insrumented executables 
(i.e. test suites) output coverage result files to disk when run. `gcov`,
`gcovr`, and `reportgenerator` (the tools managed by this plugin) all produce
their coverage tallies from these files. `gcov` is part of the GNU compiler
collection. The other tools — detailed below — require separate installation.

Ceedling’s default toolchain is the same as needed by this plugin. If you
are already running Ceedling test suites with the GNU compiler toolchain, 
you are good to go. If you are using another toolchain for test suite and/or
release builds you will need to install the GNU compiler collection to use
this plugin. Depending on your needs you may also need to install the reporting
utilities, `gcovr` and/or `reportgenerator`.

### `gcovr` and `reportgenerator`’s dependence on `gcov`

Both the `gcovr` and `reportgenerator` tools depend on the `gcov` tool. This
dependency plays out in two different ways. In both cases, the report
generation utilities ingest `gcov`’s output to produce their artifacts. As
such, `gcov` must be available in your environment if using report generation.

1. `gcovr` calls `gcov` directly.

   Because it calls `gcov` directly, you are limited as to the
   advanced Ceedling features you can employ to modify `gcov`’s execution.
   However, with a configuration option (see below) you can instruct `gcovr`
   to call something other than `gcov` (e.g. a script that intercepts and
   modifies how `gcovr` calls out to `gcov`).

   `gcovr` instructs `gcov` to generate `.gcov` files that it processes and
   discards. A `gcovr` option documented below will retain the `.gcov` files.

2. `reportgenerator` expects the existence of `.gcov` files to do its work.
   This Ceedling plugin calls `gcov` appropriately to generate the `.gcov` 
   files `reportgenerator` needs before then calling the report utility. 

   You can use Ceedling’s features to modify how `gcov` is run before 
   `reportgenerator`.

## Enable this plugin

To use this plugin it must be enabled in your Ceedling project file:

```yaml
:plugins:
  :enabled:
    - gcov
```

This simple configuration will create new `gcov:` command line tasks to run 
tests with source coverage and output simple coverage summaries to the console 
as above.

## Disabling automatic coverage summaries

To disable the coverage summaries generated immediately following `gcov:` tasks,
simply add the following to a top-level `:gcov:` section in your project
configuration file.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :summaries: FALSE
```

## Report generation

To generate reports:

1. GCovr and / or ReportGenerator must installed or otherwise ready to run in
   Ceedling’s environment.
1. Reporting options must be configured in your project file beneath a `:gcov:`
   entry.

The next sections explain each of these steps.

## Modified Condition / Decision Coverage

As of version 14, the GNU Compiler Collection supports MC/DC. If your environment
contains a minimum of GCC 14 you can enable MC/DC in coverage summaries.

If your environment contains a minimum of GCC 14 and GCovr 8, you can enable MC/DC 
in your generated coverage reports.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :mcdc: TRUE
```

### Reporting utilities installation

!!! tip "Variants of the `madsciencelab` Docker images come with these tools preinstalled"
    See [the Docker image options](../../getting-started/installation.md#madsciencelab-docker-images)
    for running Ceedling.

[gcovr] is available on any platform supported by Python.

`gcovr` can be installed via pip like this:

```shell
 > pip install gcovr
```

[ReportGenerator] is available on any platform supported by .Net.

`ReportGenerator` can be installed via .NET Core like so:

```shell
 > dotnet tool install -g dotnet-reportgenerator-globaltool
```

Either or both of `gcovr` or `ReportGenerator` may be used. Only one must 
be installed for advanced report generation.

[gcovr]: https://www.gcovr.com/
[ReportGenerator]: https://reportgenerator.io

### Enabling reporting utilities

If reports are configured (see next sections) but no `:utilities:` subsection 
exists, this plugin defaults to using `gcovr` for report generation.

Otherwise, enable Gcovr and / or ReportGenerator to create coverage reports.

```yaml
:gcov:
  :utilities:
    - gcovr           # Use `gcovr` to create reports (default if no :utilities set).
    - ReportGenerator # Use `ReportGenerator` to create reports.
```

### Automatic and manual report generation

By default, if reports are specified, this plugin automatically generates 
reports after any `gcov:` task is executed. To disable this behavior, add
`:report_task: TRUE` to your project file’s `:gcov:` configuration.

With this setting enabled, an additional Ceedling task `report:gcov` is enabled.
It may be executed after `gcov:` tasks to generate the configured reports.

For small projects, the default behavior is likely preferred. This alernative 
setting allows large or complex projects to execute potentially time intensive 
report generation only when desired.

Enabling the manual report generation task looks like this:

```yaml
:gcov:
  :report_task: TRUE
```

<br/><br/>
