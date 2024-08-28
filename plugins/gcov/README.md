# Ceedling Plugin: Gcov

This plugin integrates the code coverage abilities of the GNU compiler 
collection with test builds. It provides simple coverage metrics by default and
can optionally produce sophisticated coverage reports.

# Plugin Overview

When enabled, this plugin creates a new set of `gcov:` tasks that mirror
Ceedling's existing `test:` tasks. A `gcov:` task executes one or more tests
with coverage enabled for the source files exercised by those tests.

This plugin also provides an extensive set of options for generating various
coverage reports for your project. The simplest is text-based coverage 
summaries printed to the console after a `gcov:` test task is executed.

This document details configuration, reporting options, and provides basic
[troubleshooting help][troubleshooting].

[troubleshooting]: #advanced-configuration--troubleshooting

# Simple Coverage Summaries

In its simplest usage, this plugin outputs coverage statistics to the console
for each source file exercised by a test. These console-based coverage 
summaries are provided after the standard Ceedling test results summary. Other 
than enabling the plugin and ensuring `gcov` is installed, no further set up 
is necessary to produce these summaries.

_Note_: Automatic summaries may be disabled (see configuration options below).

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

# Advanced Coverage Reports

For more advanced visualizations and reporting, this plugin also supports a 
variety of report generation options.

Advanced report generation uses [gcovr] and / or [ReportGenerator] to generate
HTML, XML, JSON, or text-based reports from coverage-instrumented test runs. 
See the tools' respective sites for examples of the reports they can generate.

In the default configuration, if reports are enabled, this plugin automatically
generates reports in the build's `artifacts/` directory after each execution of
a `gcov:` task.

An optional setting documented below disables automatic report generation, 
providing a separate Ceedling task instead. Reports can then be generated
on demand after test suite runs.

[gcovr]: https://www.gcovr.com/
[ReportGenerator]: https://reportgenerator.io

# Important Notes on Coverage Summaries vs. Coverage Reports

Coverage summaries and coverage reports provide different levels of fidelity
and usability. Summaries are relatively unsophisticated while reports are 
sophisticated. As such, both provide different capabilities and levels of 
usability.

## Coverage summaries

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

## Coverage reports

Coverage reports provide both much more detail and better overviews of coverage
than the console-based coverage summaries. However, with this comes the need
for more sophisticated configuration and certain caveats on what is reported.

Later sections detail how to configure the reports this plugin can generate.

Of note is a consequence of how reports are generated and the limits of the
tools that do so. Reports are generated using coverage results on disk. The
report generation tools slurp up the coverage results they find in the `gcov/`
build output directory. This means that previous test suite runs can “pollute”
coverage reports. The solution is simple if blunt — run the `clobber` task
before running a coverage-instrumented test suite. This will yield a coverage
report with scope that matches that of the test suite you run.

Both the `gcovr` and `reportgeneator` reporting utilities include powerful
filters that can limit the scope of reports. Hypothetically, it's possible for
coverage reports to have the same clear scope as coverage summaries. However,
in large projects, these filters would cause impractically long command lines.
Both tools provide configuration file options that would solve the command line
problem. However, this feature is “experimental” for `gcovr` and considerable 
work to implement for both reporting utilities. At present, running 
`ceedling clobber` before generating reports is the best option to ensure 
accurate reports.

# Plugin Set Up & Configuration

## Supported tool versions [May 10, 2024]

At the time of the last major updates to the Gcov plugin, the following notes
on version compatibility were known to be accurate.

Keep in mind that for proper functioning, you do not necessarily need to
install all the tooks the Gcov plugin works with. Depending on configuration
options documented in later sections, any of the following tool combinations
may be sufficient for your needs:

1. `gcov`
1. `gcov` + `gcovr`
1. `gcov` + `reportgenerator`
1. `gcov` + `gcovr` + `reportgenerator`

### `gcov`

The Gcov plugin is known to work with `gcov` packaged with GNU Compiler
Collection 12.2 and should work with versions through at least 14.

The maintainers of `gcov` introduced significant behavioral changes for version
12. Previous versions of `gcov` had a simple exit code scheme with only a
single non-zero exit code upon fatal errors. Since version 12 `gcov` emits a
variety of exit codes even if the noted issue is a non-fatal error. The Gcov
plugin’s logic assumes version 12 behavior and processes failure messages and
exit codes appropriately, taking into account plugin configuration options.

The Gcov plugin should be compatible with versions of `gcov` before version 12.
That is, its improved `gcov` exit handling should not be broken by the prior
simpler behavior. The Gcov plugin dependes on the `gcov` command line and has
been compatible with it as far back as `gcov` version 7.

Because long file paths are quite common in software development scenarios, by
default, the Gcov plugin depends on the `gcov` `-x` flag. This flag hashes long
file paths to ensure they are not a problem for certain platforms' file
systems. This flag became available with `gcov` version 7. At the time of this
README section’s last update, the GNU Compiler Collection was at version 14. We
do not recommend using `gcov` version 6 and earlier. And, in fact, because of
the Gcov plugin’s dependence on the `gcov` `-x` flag, attempting to use it will
fail.

### `gcovr`

The Gcov plugin is known to work with `gcovr` 5.2 through `gcovr` 6.x. The
Gcov plugin supports `gcovr` command line conventions since version 4.2 and
attempts to support `gcovr` command lines before version 4.2. We recommend 
using `gcovr` 5 and later. 

### `reportgenerator`

The Gcov plugin is known to work with `reportgenerator` 5.2.4. The command line
for executing `reportgenerator` that the Gcov plugin relies on has largely been
stable since version 4. We recommend using `reportgenerator` 5.0 and later.

## Toolchain dependencies

### GNU Compiler Collection

This plugin relies on the GNU compiler collection. Coverage instrumentation
is enabled through `gcc` compiler flags. Coverage-insrumented executables 
(i.e. test suites) output coverage result files to disk when run. `gcov`,
`gcovr`, and `reportgenerator` (the tools managed by this plugin) all produce
their coverage tallies from these files. `gcov` is part of the GNU compiler
collection. The other tools — detailed below — require separate installation.

Ceedling's default toolchain is the same as needed by this plugin. If you
are already running Ceedling test suites with the GNU compiler toolchain, 
you are good to go. If you are using another toolchain for test suite and/or
release builds you will need to install the GNU compiler collection to use
this plugin. Depending on your needs you may also need to install the reporting
utilities, `gcovr` and/or `reportgenerator`.

### `gcovr` and `reportgenerator`’s dependence on `gcov`

Both the `gcovr` and `reportgenerator` tools depend on the `gcov` tool. This
dependency plays out in two different ways. In both cases, the report
generation utilities ingest `gcov`'s output to produce their artifacts. As
such, `gcov` must be available in your environment if using report generation.

1. `gcovr` calls `gcov` directly.

   Because it calls `gcov` directly, you are limited as to the
   advanced Ceedling features you can employ to modify `gcov`'s execution.
   However, with a configuration option (see below) you can instruct `gcovr`
   to call something other than `gcov` (e.g. a script that intercepts and
   modifies how `gcovr` calls out to `gcov`).

   `gcovr` instructs `gcov` to generate `.gcov` files that it processes and
   discards. A `gcovr` option documented below will retain the `.gcov` files.

2. `reportgenerator` expects the existence of `.gcov` files to do its work.
   This Ceedling plugin calls `gcov` appropriately to generate the `.gcov` 
   files `reportgenerator` needs before then calling the report utility. 

   You can use Ceedling's features to modify how `gcov` is run before 
   `reportgenerator`.

## Enable this plugin

To use this plugin it must be enabled in your Ceedling project file:

```yaml
:plugins:
  :enabled:
    - gcov
```

This simple configuration will create new `gcov:` tasks to run tests with 
source coverage and output simple coverage summaries to the console as above.

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
   Ceedling's environment.
1. Reporting options must be configured in your project file beneath a `:gcov:`
   entry.

The next sections explain each of these steps.

### Installation of report generation utilities

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

## Enabling report generation utilities

If reports are configured (see next sections) but no `:utilities:` subsection 
exists, this plugin defaults to using `gcovr` for report generation.

Otherwise, enable Gcovr and / or ReportGenerator to create coverage reports.

```yaml
:gcov:
  :utilities:
    - gcovr           # Use `gcovr` to create reports (default if no :utilities set).
    - ReportGenerator # Use `ReportGenerator` to create reports.
```

## Automatic and manual report generation

By default, if reports are specified, this plugin automatically generates 
reports after any `gcov:` task is executed. To disable this behavior, add
`:report_task: TRUE` to your project file's `:gcov:` configuration.

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

# Example Usage

_Note_: Unless disabled, basic coverage summaries are always printed to the 
console regardless of report generation options.

## Automatic report generation (default)

If coverage report generation is configured, the plugin defaults to running 
reports after any `gcov:` task.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :utilities:
    - gcovr            # Enabled by default -- shown for completeness
  :report_task: FALSE  # Disabled by default -- shown for completeness
  :reports:            # See later section for report configuration
    - HtmlBasic

  ...                  # Further configuration for reporting (not shown)

```

```shell
 > ceedling gcov:all
```

## Report generation configured as manual task

If the `:report_task:` configuration option is enabled, reports are not 
automatically generaed after test suite coverage builds. Instead, report 
generation is triggered by the `report:gcov` task.

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :utilities:
    - gcovr            # Enabled by default -- shown for completeness
  :report_task: TRUE
  :reports:            # See later section for report configuration
    - HtmlBasic        # Enabled by default -- shown for completeness

  ...                  # Further configuration for reporting (not shown)

```

With the separate reporting task enabled, it can be used like any other Ceedling task.

```shell
 > ceedling gcov:all report:gcov
```

or 

```shell
 > ceedling gcov:all

 > ceedling report:gcov
```

### Full report generation configuration example

```yaml
:plugins:
  :enabled:
    - gcov

:gcov:
  :summaries: FALSE              # Simple coverage summaries to console disabled
  :reports:                      # `gcovr` tool enabled by default
    - HtmlDetailed
    - Text
    - Cobertura
  :gcovr:                        # `gcovr` common and report-specific options
    :report_root: "../../"       # Atypical layout -- project.yml is inside a subdirectoy below <build root>
    :sort_percentage: TRUE
    :sort_uncovered: FALSE
    :html_medium_threshold: 60
    :html_high_threshold: 85
    :print_summary: TRUE
    :threads: 4
    :keep: FALSE
```

# Report Generation Configuration

Various reports are available. Each must be enabled in `:gcov` ↳ `:reports`.

If no report types are specified, report generation (but not coverage summaries) 
is disabled regardless of any other setting.

Most report types can only be generated by `gcovr` or `ReportGenerator`. Some 
can be generated by both. This means that your selection of report is impacted by
which generation utility is enabled. In fact, in some cases, the same report type 
could be generated by each utility (to different artifact build output folders).

Reports are configured with:

1. General or common options for each report generation utility
1. Specific options for types of report per each report generation utility

These are detailed in the sections that follow. See the 
[GCovr User Guide][gcovr-user-guide] and the 
[ReportGenerator Wiki][report-generator-wiki] for full details.

[gcovr-user-guide]: https://www.gcovr.com/en/stable/guide.html
[report-generator-wiki]: https://github.com/danielpalme/ReportGenerator/wiki

```yaml
:gcov:
  # Specify one or more reports to generate.
  # Defaults to HtmlBasic.
  :reports:
    # Generate an HTML summary report.
    # Supported utilities: gcovr, ReportGenerator
    - HtmlBasic

    # Generate an HTML report with line by line coverage of each source file.
    # Supported utilities: gcovr, ReportGenerator
    - HtmlDetailed

    # Generate a Text report, which may be output to the console with gcovr or a file in both gcovr and ReportGenerator.
    # Supported utilities: gcovr, ReportGenerator
    - Text

    # Generate a Cobertura XML report.
    # Supported utilities: gcovr, ReportGenerator
    - Cobertura

    # Generate a SonarQube XML report.
    # Supported utilities: gcovr, ReportGenerator
    - SonarQube

    # Generate a JSON report.
    # Supported utilities: gcovr
    - JSON

    # Generate a detailed HTML report with CSS and JavaScript included in every HTML page. Useful for build servers.
    # Supported utilities: ReportGenerator
    - HtmlInline

    # Generate a detailed HTML report with a light theme and CSS and JavaScript included in every HTML page for Azure DevOps.
    # Supported utilities: ReportGenerator
    - HtmlInlineAzure

    # Generate a detailed HTML report with a dark theme and CSS and JavaScript included in every HTML page for Azure DevOps.
    # Supported utilities: ReportGenerator
    - HtmlInlineAzureDark

    # Generate a single HTML file containing a chart with historic coverage information.
    # Supported utilities: ReportGenerator
    - HtmlChart

    # Generate a detailed HTML report in a single file.
    # Supported utilities: ReportGenerator
    - MHtml

    # Generate SVG and PNG files that show line and / or branch coverage information.
    # Supported utilities: ReportGenerator
    - Badges

    # Generate a single CSV file containing coverage information per file.
    # Supported utilities: ReportGenerator
    - CsvSummary

    # Generate a single TEX file containing a summary for all files and detailed reports for each files.
    # Supported utilities: ReportGenerator
    - Latex

    # Generate a single TEX file containing a summary for all files.
    # Supported utilities: ReportGenerator
    - LatexSummary

    # Generate a single PNG file containing a chart with historic coverage information.
    # Supported utilities: ReportGenerator
    - PngChart

    # Command line output interpreted by TeamCity.
    # Supported utilities: ReportGenerator
    - TeamCitySummary

    # Generate a text file in lcov format.
    # Supported utilities: ReportGenerator
    - lcov

    # Generate a XML file containing a summary for all classes and detailed reports for each class.
    # Supported utilities: ReportGenerator
    - Xml

    # Generate a single XML file containing a summary for all files.
    # Supported utilities: ReportGenerator
    - XmlSummary
```

## Gcovr report output

All reports generated by `gcovr` are found in `<build root>/artifacts/gcov/gcovr/`.

## Gcovr HTML reports

Generation of HTML reports may be modified with the following configuration items.

```yaml
:gcov:
  :gcovr:
    # HTML report filename.
    :html_artifact_filename: <filename>

    # Use 'title' as title for the HTML report.
    # Default is 'Head'. (gcovr --html-title)
    :html_title: <title>

    # If the coverage is below MEDIUM, the value is marked as low coverage in the HTML report.
    # MEDIUM has to be lower than or equal to value of html_high_threshold.
    # If MEDIUM is equal to value of html_high_threshold the report has only high and low coverage.
    # Default is 75.0. (gcovr --html-medium-threshold)
    :html_medium_threshold: 75

    # If the coverage is below HIGH, the value is marked as medium coverage in the HTML report.
    # HIGH has to be greater than or equal to value of html_medium_threshold.
    # If HIGH is equal to value of html_medium_threshold the report has only high and low coverage.
    # Default is 90.0. (gcovr -html-high-threshold)
    :html_high_threshold: 90

    # Set to 'true' to use absolute paths to link the 'detailed' reports.
    # Defaults to relative links. (gcovr --html-absolute-paths)
    :html_absolute_paths: <true|false>

    # Override the declared HTML report encoding. Defaults to UTF-8. (gcovr --html-encoding)
    :html_encoding: <html_encoding>
```

## Gcovr Cobertura XML reports

Generation of Cobertura XML reports may be modified with the following configuration items.

```yaml
:gcov:
  :gcovr:
    # Set to 'true' to pretty-print the Cobertura XML report, otherwise set to 'false'.
    # Defaults to disabled. (gcovr --xml-pretty)
    :cobertura_pretty: <true|false>

    # Override default Cobertura XML report filename.
    :cobertura_artifact_filename: <filename>
```

## Gcovr SonarQube XML reports

Generation of SonarQube XML reports may be modified with the following configuration items.

```yaml
:gcov:
  :gcovr:
    # Override default SonarQube XML report filename.
    :sonarqube_artifact_filename: <filename>
```

## Gcovr JSON reports

Generation of JSON reports may be modified with the following configuration items.

```yaml
:gcov:
  :gcovr:
    # Set to 'true' to pretty-print the JSON report, otherwise set 'false'.
    # Defaults to disabled. (gcovr --json-pretty)
    :json_pretty: <true|false>

    # Override default JSON report filename.
    :json_artifact_filename: <filename>
```

## Gcovr text reports

Generation of text reports may be modified with the following configuration items.
Text reports may be printed to the console or output to a file.

```yaml
:gcov:
  :gcovr:
    # Override default text report filename.
    :text_artifact_filename: <filename>
```

## Common gcovr options

A number of options exist to control which files are considered part of a 
coverage report. This Ceedling gcov plugin itself handles the most important 
aspect — only source files under test are compiled with coverage. Tests, mocks,
and test runners, are not compiled with coverage.

**Note:** `gcovr` will only accept a single path for `:report_root`. In typical
usage, this is of no concern as it is handled automatically. In unusual project
layouts, you may need to specify a folder that encompasses _all_ build folders 
containing coverage result files and optionally, selectively exclude patterns
of paths or files. For instance, if your Ceedling project file is not at the 
root of your project, you may need set `:report_root` as well as 
`:report_exclude` and `:exclude_directories`.

```yaml
:gcov:
  :gcovr:
    # The root directory of your source files. Defaults to ".", the current directory.
    # File names are reported relative to this root. The report_root is the default report_include.
    # Default if unspecified: "."
    :report_root: <path>

    # Load the specified configuration file.
    # Defaults to gcovr.cfg in the report_root directory. (gcovr --config)
    :config_file: <config_file>

    # Exit with a status of 2 if the total line coverage is less than MIN percentage.
    # Can be ORed with exit status of other fail options. (gcovr --fail-under-line)
    :fail_under_line: <1-100>

    # Exit with a status of 4 if the total branch coverage is less than MIN percentage.
    # Can be ORed with exit status of other fail options. (gcovr --fail-under-branch)
    :fail_under_branch: <1-100>

    # Exit with a status of 8 if the total decision coverage is less than MIN percentage.
    # Can be ORed with exit status of other fail options. (gcovr --fail-under-decision)
    :fail_under_decision: <1-100>

    # Exit with a status of 16 if the total function coverage is less than MIN percentage.
    # Can be ORed with exit status of other fail options. (gcovr --fail-under-function)
    :fail_under_function: <1-100>

    # If the fail options above are set, specify whether those conditions should break a build.
    # The default option is false and simply logs a warning without breaking the build.
    :exception_on_fail: <true|false>

    # Select the source file encoding.
    # Defaults to the system default encoding (UTF-8). (gcovr --source-encoding)
    :source_encoding: <encoding>

    # Report the branch coverage instead of the line coverage. For text report only. (gcovr --branches).
    :branches: <true|false>

    # Sort entries by increasing number of uncovered lines.
    # For text and HTML report. (gcovr --sort-uncovered)
    :sort_uncovered: <true|false>

    # Sort entries by increasing percentage of uncovered lines.
    # For text and HTML report. (gcovr --sort-percentage)
    :sort_percentage: <true|false>

    # Print a small report to stdout with line & branch percentage coverage.
    # This is in addition to other reports. (gcovr --print-summary).
    :print_summary: <true|false>

    # Keep only source files that match this filter. (gcovr --filter).
    # Filters are regular expressions (ex: "^src")
    :report_include: <filter>

    # Exclude source files that match this filter. (gcovr --exclude).
    # Filters are regular expressions (ex: "^vendor.*|^build.*|^test.*|^lib.*")
    :report_exclude: <filter>

    # Keep only gcov data files that match this filter. (gcovr --gcov-filter).
    # Filters are regular expressions
    :gcov_filter: <filter>

    # Exclude gcov data files that match this filter. (gcovr --gcov-exclude).
    # Filters are regular expressions
    :gcov_exclude: <filter>

    # Exclude directories that match this filter while searching 
    # raw coverage files. (gcovr --exclude-directories).
    # Filters are regular expressions
    :exclude_directories: <filters>

    # Use a particular gcov executable. (gcovr --gcov-executable).
    # (This may be appropriate and necessary in special circumstances.
    #  Please review Ceedling's options for modifying tools first.)
    :gcov_executable: <cmd>

    # Exclude branch coverage from lines without useful
    # source code. (gcovr --exclude-unreachable-branches).
    :exclude_unreachable_branches: <true|false>

    # For branch coverage, exclude branches that the compiler
    # generates for exception handling. (gcovr --exclude-throw-branches).
    :exclude_throw_branches: <true|false>

    # For Gcovr 6.0+, multiple instances of the same function in coverage results can
    # cause a fatal error. Since Ceedling can test multiple build variations of the
    # same source function, this is bad.
    # Default value for Gcov plugin is 'merge-use-line-max'. See Gcovr docs for more.
    # https://gcovr.com/en/stable/guide/merging.html
    :merge_mode_function: <...>

    # Use existing gcov files for analysis. Default: False. (gcovr --use-gcov-files)
    :use_gcov_files: <true|false>

    # Skip lines with parse errors in GCOV files instead of
    # exiting with an error. (gcovr --gcov-ignore-parse-errors).
    :gcov_ignore_parse_errors: <true|false>

    # Override normal working directory detection. (gcovr --object-directory)
    :object_directory: <path>

    # Keep gcov files after processing. (gcovr --keep).
    :keep: <true|false>

    # Delete gcda files after processing. (gcovr --delete).
    :delete: <true|false>

    # Set the number of threads to use in parallel. (gcovr -j).
    :threads: <count>
```

## ReportGenerator configuration

The `ReportGenerator` utility may be configured with the following configuration items.

All generated reports are found in `<build root>/artifacts/gcov/ReportGenerator/`.

```yaml
:gcov:
  :report_generator:
    # Optional directory for storing persistent coverage information.
    # Can be used in future reports to show coverage evolution.
    :history_directory: <path>

    # Optional plugin files for custom reports or custom history storage (separated by semicolon).
    :plugins: <plugin.dll>;<*.dll>

    # Optional list of assemblies that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    :assembly_filters: +<included>;-<excluded>

    # Optional list of classes that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    :class_filters: +<included>;-<excluded>

    # Optional list of files that should be included or excluded in the report (separated by semicolon).
    # Exclusion filters take precedence over inclusion filters.
    # Wildcards are allowed, but not regular expressions.
    # Example: "-./vendor/*;-./build/*;-./test/*;-./lib/*;+./src/*"
    :file_filters: +<included>;-<excluded>

    # The verbosity level of the log messages.
    # Values: Verbose, Info, Warning, Error, Off (defaults to Warning)
    :verbosity: <level>

    # Optional tag or build version.
    :tag: <tag>

    # Optional list of one or more regular expressions to exclude gcov notes files that match these filters.
    :gcov_exclude:
      - <regex>
      - ...

    # Optionally set the number of threads to use in parallel. Defaults to 1.
    :threads: <count>

    # Optional list of one or more command line arguments to pass to Report Generator.
    # Useful for configuring Risk Hotspots and Other Settings.
    # https://github.com/danielpalme/ReportGenerator/wiki/Settings
    # Note: This can be accomplished with Ceedling's tool configuration options outside of plugin 
    #       configuration but is supported here to collect configuration options in one place.
    :custom_args:
      - <argument>
      - ...
```

# Advanced Configuration & Troubleshooting

See the _Ceedling Cookbook_ for options on how to use Ceedling's advanced 
features to modify how this plugin is configured, especially tool 
configurations.

Details of interest for this plugin to be modified or made use of using 
Ceedling's advanced features are primarily contained in 
[defaults_gcov.rb](conig/defaults_gcov.rb) and [defaults.yml](config/defaults.yml).

## “gcovr not found”

`gcovr` is a Python-based application. Depending on the particulars of its 
installation and your platform, you may encounter a “gcovr not found” error. 
This is usually related to complications of running a Python script as an 
executable.

### Check your `PATH`

The problem may be as simple to solve as ensuring your user or system path 
include the path to `python` and/or the `gcovr` script. `gcovr` may be 
successfully installed and findable by Python; this does not necessarily 
mean that shell commands Ceedling spawns can find these tools.

Options:

1. Modify your user or system path to include your Python installation, `gcovr`
   location, or both.
1. Use Ceedling's `:environment` project configuration with its special 
   handling of `PATH` to modify the search path Ceedling accesses when it 
   executes shell commands. xample below.

```yaml
:environment:
  - :path:               # Concatenates the following with OS-specific path separator             
     - <path to add>     # Add Python and/or `gcovr` path
     - "#{ENV['PATH']}"  # Fetch existing path entries
```

### Redefine `gcovr` to call Python directly

Another solution is simple in concept. Instead of calling `gcovr` directly, call 
`python` with the `gcovr` script as a command line argument (followed by all of 
the configured `gcovr` arguments).

To implement the solution, we make use of two features:

* `gcovr`'s tool `:executable` definition that looks up an environment variable.
* Ceedling's `:environment` settings to redefine `gcovr`.

Gcovr's tool defintion, like many of Ceedling's tool defintions, defaults to an
environment variable (`GCOVR`) if it is defined. If we set that environment
variable to call Python with the path to the `gcovr` script, Ceedling will call
that instead of only `gcovr`. Ceedling enables you to set environment variables
that only exist while it runs.

In your project file:

```yaml
:environment:
  # Fill in / omit paths on your system as appropritate to your circumstances
  - :gcovr: <path>/python <path>/gcovr
```

Alternatively, a slightly more elegant approach may work in some cases:

```yaml
:environment:
  - ":gcovr: python #{`which gcovr`}" # Shell out to look up the path to gcovr
```

A variation of this concept relies on Python's knowledge of its runtime
environment and packages:

```yaml
:environment:
  - :gcovr: python -m gcovr # Call the gcovr module
```

# References

Much of the text describing report generations options in this document was 
taken from the [Gcovr User Guide][gcovr-user-guide] and the
[ReportGenerator Wiki][report-generator-wiki].

The text is repeated here to provide as useful documenation as possible.
